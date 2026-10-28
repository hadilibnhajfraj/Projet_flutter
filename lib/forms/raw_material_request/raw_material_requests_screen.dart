// lib/forms/raw_material_request/raw_material_requests_screen.dart
//
// Menu « Matières premières » — suivi des demandes de matières premières :
// tableau (une ligne par matière, valeurs individuelles, informations de la
// demande répétées sur chaque ligne),
// filtres (période, utilisateur, poste, matière, statut), recherche par
// numéro, export Excel (backend, même mécanisme que Contrôle Qualité) et
// fiche détaillée avec l'historique des statuts. Données réelles uniquement
// (GET /raw-material-requests) ; visibilité et changements de statut
// contrôlés par le backend.

import 'dart:async';
import 'dart:typed_data';

import 'package:dash_master_toolkit/services/socket_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/quality_control/service/qc_file_saver.dart';

import 'raw_material_evening_prompt.dart' show RawMaterialEveningDialog, kRawMaterialEveningColor;
import 'raw_material_request_dialog.dart' show RawMaterialRequestDialog;
import 'raw_material_request_form.dart' show kRawMaterials, kRawMaterialHeaderColor, formatRawMaterialQuantity, rmT;
import 'raw_material_request_record.dart';
import 'raw_material_request_service.dart' show RawMaterialRejection, RawMaterialRequestService;
import 'raw_material_tracking_service.dart';

typedef RawMaterialFileSaver = Future<void> Function(Uint8List bytes, String fileName, String mimeType);

const _kXlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
const _kGrid = Color(0xFF94A3B8);

String _dateTime(DateTime? d) => d == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
String _day(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  return d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);
}

String _qty(double? v) => v == null ? '—' : formatRawMaterialQuantity(v);

class RawMaterialStatusChip extends StatelessWidget {
  final String status;
  const RawMaterialStatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = rawMaterialStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        rmT(context, rawMaterialStatusLabel(status)),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class RawMaterialRequestsScreen extends StatefulWidget {
  /// Injections pour les tests ; par défaut, API réelle et téléchargement navigateur.
  final RawMaterialTrackingApi? api;
  final RawMaterialFileSaver? saveFile;
  /// Demande ouverte directement (lien d'une notification : `?id=`).
  final String? initialRequestId;

  const RawMaterialRequestsScreen({super.key, this.api, this.saveFile, this.initialRequestId});

  @override
  State<RawMaterialRequestsScreen> createState() => _RawMaterialRequestsScreenState();
}

class _RawMaterialRequestsScreenState extends State<RawMaterialRequestsScreen> {
  late final RawMaterialTrackingApi _api = widget.api ?? RawMaterialTrackingService.instance;

  RawMaterialPermissions? _perms;
  RawMaterialFilters _filters = const RawMaterialFilters();
  List<RawMaterialRequestRecord> _items = const [];
  int _total = 0;
  List<({String userId, String userEmail})> _requesters = const [];
  final _search = TextEditingController();
  final _horizontal = ScrollController();
  Timer? _debounce;
  bool _loading = true;
  bool _exporting = false;
  // Bandeau du responsable : demandes en attente / en retard / échéance proche.
  ({int pending, int overdue, int dueSoon})? _summary;
  String? _error;
  int _loadSeq = 0;

  String _t(String key) => rmT(context, key);

  @override
  void initState() {
    super.initState();
    SocketService.instance.on('raw-material-request:updated', _onRemoteUpdate);
    _init();
  }

  // Demande créée ou traitée par un autre responsable : relecture immédiate.
  late final void Function(dynamic) _onRemoteUpdate = (_) {
    if (mounted && _perms?.canView == true) _load();
  };

  @override
  void dispose() {
    SocketService.instance.off('raw-material-request:updated', _onRemoteUpdate);
    _debounce?.cancel();
    _search.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final perms = await _api.permissions();
      if (!mounted) return;
      setState(() => _perms = perms);
      if (!perms.canView) {
        setState(() => _loading = false);
        return;
      }
      if (perms.fullVisibility) {
        _api.requesters().then((r) {
          if (mounted) setState(() => _requesters = r);
        }).catchError((_) {});
      }
      await _load();
      final id = widget.initialRequestId;
      if (id != null && id.isNotEmpty && mounted) await _openDetailById(id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = RawMaterialRequestService.friendlyError(e);
      });
    }
  }

  Future<void> _openDetailById(String id) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => RawMaterialRequestDetailDialog(requestId: id, api: _api, permissions: _perms ?? const RawMaterialPermissions()),
    );
    if (changed == true) _load();
  }

  void _loadSummary() {
    _api.pendingSummary().then((s) {
      if (mounted) setState(() => _summary = s);
    }).catchError((_) {});
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    if (_perms?.fullVisibility == true) _loadSummary();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _api.list(_filters);
      if (!mounted || seq != _loadSeq) return; // réponse d'un filtre déjà remplacé
      setState(() {
        _items = r.items;
        _total = r.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _loading = false;
        _error = RawMaterialRequestService.friendlyError(e);
      });
    }
  }

  void _apply(RawMaterialFilters f) {
    _filters = f.copyWith(page: 1);
    _load();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _apply(_filters.copyWith(search: v)));
  }

  void _reset() {
    _search.clear();
    _apply(const RawMaterialFilters());
  }

  void _goToPage(int page) {
    _filters = _filters.copyWith(page: page);
    _load();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await _api.exportExcel(_filters);
      await (widget.saveFile ?? saveQcFile)(file.bytes, file.fileName, _kXlsxMime);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_t('Export impossible')} : ${RawMaterialRequestService.friendlyError(e)}'),
        backgroundColor: kCrmDanger,
      ));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _openDetail(RawMaterialRequestRecord r) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => RawMaterialRequestDetailDialog(requestId: r.id, api: _api, permissions: _perms ?? const RawMaterialPermissions()),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 16),
              if (_perms != null && !_perms!.canView)
                _message(Icons.lock_outline_rounded, _t("Vous n'avez pas accès au suivi des demandes de matières premières."))
              else ...[
                if ((_summary?.pending ?? 0) > 0) _pendingBanner(),
                _filtersCard(),
                const SizedBox(height: 16),
                _tableCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        spacing: 12,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kRawMaterialHeaderColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.inventory_2_outlined, color: kRawMaterialHeaderColor),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_t('Matières premières'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kCrmText)),
              Text(_t('Suivi des demandes de matières premières'), style: const TextStyle(fontSize: 13, color: kCrmTextSub)),
            ]),
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton.icon(
              key: const ValueKey('raw-material-export'),
              onPressed: _exporting || _perms?.canView != true ? null : _export,
              icon: _exporting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_download_outlined),
              label: Text(_t('Exporter Excel')),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: _t('Actualiser'),
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ]),
        ],
      );

  Widget _pendingBanner() {
    final s = _summary!;
    final color = s.overdue > 0 ? kCrmDanger : (s.dueSoon > 0 ? kCrmWarning : kRawMaterialPendingColor);
    final parts = [
      '${s.pending} ${_t(s.pending > 1 ? 'demandes en attente de validation' : 'demande en attente de validation')}',
      if (s.overdue > 0) '${s.overdue} ${_t('en retard (échéance vendredi 14 h dépassée)')}',
      if (s.dueSoon > 0) '${s.dueSoon} ${_t('à échéance proche')}',
    ];
    return Container(
      key: const ValueKey('pending-banner'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        Icon(s.overdue > 0 ? Icons.alarm_rounded : Icons.pending_actions_rounded, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(parts.join(' — '), style: const TextStyle(fontWeight: FontWeight.w700, color: kCrmText))),
        TextButton(
          onPressed: () => _apply(_filters.copyWith(status: 'PENDING_VALIDATION')),
          child: Text(_t('Afficher')),
        ),
      ]),
    );
  }

  BoxDecoration get _card => BoxDecoration(
        color: kCrmSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCrmBorder),
      );

  Widget _filtersCard() {
    final f = _filters;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _dateFilter('from', 'Du', f.from, (d) => _apply(f.copyWith(from: d)), () => _apply(f.copyWith(clear: {'from'}))),
          _dateFilter('to', 'Au', f.to, (d) => _apply(f.copyWith(to: d)), () => _apply(f.copyWith(clear: {'to'}))),
          if (_perms?.fullVisibility == true)
            _dropdown('userId', 'Utilisateur', f.userId, [
              (null, _t('Tous')),
              for (final r in _requesters) (r.userId, r.userEmail),
            ], (v) => _apply(v == null ? f.copyWith(clear: {'userId'}) : f.copyWith(userId: v)), width: 260),
          _dropdown('poste', 'Poste', f.poste, [
            (null, _t('Tous')),
            ('matin', _t('Matin')),
            ('nuit', _t('Soir')),
          ], (v) => _apply(v == null ? f.copyWith(clear: {'poste'}) : f.copyWith(poste: v))),
          _dropdown('material', 'Matière première', f.material, [
            (null, _t('Toutes')),
            for (final (code, label) in kRawMaterials) (code, label),
          ], (v) => _apply(v == null ? f.copyWith(clear: {'material'}) : f.copyWith(material: v))),
          _dropdown('status', 'Statut', f.status, [
            (null, _t('Tous')),
            for (final e in kRawMaterialStatuses.entries) (e.key, _t(e.value.$1)),
          ], (v) => _apply(v == null ? f.copyWith(clear: {'status'}) : f.copyWith(status: v)), width: 220),
          SizedBox(
            width: 230,
            child: TextField(
              key: const ValueKey('filter-search'),
              controller: _search,
              onChanged: _onSearch,
              decoration: _inputDecoration(_t('N° de demande'), prefix: Icons.search_rounded),
            ),
          ),
          if (!f.isEmpty)
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: Text(_t('Réinitialiser')),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? prefix, Widget? suffix}) => InputDecoration(
        labelText: label,
        isDense: true,
        prefixIcon: prefix == null ? null : Icon(prefix, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: kCrmBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kCrmBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kCrmBorder)),
      );

  Widget _dateFilter(String key, String label, DateTime? value, ValueChanged<DateTime> onPick, VoidCallback onClear) =>
      SizedBox(
        width: 170,
        child: InkWell(
          key: ValueKey('filter-$key'),
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? now,
              firstDate: DateTime(2024),
              lastDate: DateTime(now.year + 1, 12, 31),
            );
            if (picked != null) onPick(picked);
          },
          child: InputDecorator(
            decoration: _inputDecoration(
              _t(label),
              prefix: Icons.event_outlined,
              suffix: value == null
                  ? null
                  : IconButton(
                      key: ValueKey('filter-$key-clear'),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: onClear,
                    ),
            ),
            child: Text(value == null ? '—' : DateFormat('dd/MM/yyyy').format(value)),
          ),
        ),
      );

  Widget _dropdown(String key, String label, String? value, List<(String?, String)> options, ValueChanged<String?> onChanged,
          {double width = 190}) =>
      SizedBox(
        width: width,
        child: InputDecorator(
          decoration: _inputDecoration(_t(label)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              key: ValueKey('filter-$key'),
              value: options.any((o) => o.$1 == value) ? value : null,
              isDense: true,
              isExpanded: true,
              items: [
                for (final (v, text) in options)
                  DropdownMenuItem<String?>(value: v, child: Text(text, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      );

  Widget _message(IconData icon, String text, {Widget? action}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        decoration: _card,
        child: Column(children: [
          Icon(icon, size: 40, color: kCrmTextSub),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: kCrmTextSub, fontSize: 14)),
          if (action != null) ...[const SizedBox(height: 12), action],
        ]),
      );

  // ── Tableau ─────────────────────────────────────────────────────────────
  // Une ligne par matière avec ses valeurs telles qu'enregistrées (jamais de
  // total) ; les informations de la demande sont répétées sur chaque ligne,
  // les lignes d'une même demande partagent le même fond. Colonne 0 : fiche
  // détaillée de la demande, en tête pour rester visible sans défilement.
  static const _columns = [
    ('', 48.0),
    ('N° demande', 145.0),
    ('Date et heure de la demande', 125.0),
    ('Demandeur', 210.0),
    ('Poste', 72.0),
    ('Date de production', 108.0),
    ('Matière première', 140.0),
    ('Référence', 110.0),
    ('Lot', 100.0),
    ('Quantité disponible (KG)', 112.0),
    ('Besoin de production (KG)', 112.0),
    ('Quantité demandée (KG)', 112.0),
    ('Quantité réelle (KG)', 112.0),
    ('Unité', 64.0),
    ('Statut', 175.0),
    ('Date et heure de validation', 125.0),
  ];

  // Filtre « Matière première » : uniquement les lignes de cette matière.
  // Une demande sans matière enregistrée garde une ligne (valeurs « — »).
  List<RawMaterialItem?> _lines(RawMaterialRequestRecord r) {
    final items = _filters.material == null ? r.items : r.items.where((i) => i.material == _filters.material).toList();
    return items.isEmpty ? const [null] : items;
  }

  Widget _tableCard() {
    if (_loading && _items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48),
        decoration: _card,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return _message(Icons.error_outline_rounded, '${_t('Chargement impossible')} : $_error',
          action: OutlinedButton(onPressed: _load, child: Text(_t('Réessayer'))));
    }
    if (_items.isEmpty) {
      return _message(Icons.inbox_outlined,
          _filters.isEmpty ? _t('Aucune demande de matières premières enregistrée.') : _t('Aucune demande ne correspond aux filtres.'));
    }
    final width = _columns.fold<double>(0, (s, c) => s + c.$2);
    return Container(
      decoration: _card,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Scrollbar(
            controller: _horizontal,
            thumbVisibility: true,
            child: SingleChildScrollView(
              key: const ValueKey('raw-material-requests-scroll'),
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: width, child: _table()),
            ),
          ),
          _pagination(),
        ],
      ),
    );
  }

  Widget _table() {
    const side = BorderSide(color: _kGrid, width: 0.6);
    return Table(
      key: const ValueKey('raw-material-requests-table'),
      border: const TableBorder(horizontalInside: side, verticalInside: side, bottom: side),
      columnWidths: {for (var i = 0; i < _columns.length; i++) i: FixedColumnWidth(_columns[i].$2)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(color: kRawMaterialHeaderColor),
          children: [
            for (final (label, _) in _columns)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Text(
                  label.isEmpty ? '' : _t(label),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
              ),
          ],
        ),
        for (final (g, r) in _items.indexed)
          for (final (k, item) in _lines(r).indexed) _line(r, item, group: g, first: k == 0),
      ],
    );
  }

  Widget _cell(String text, {Key? key, bool bold = false, TextAlign align = TextAlign.center, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Text(
          text,
          key: key,
          textAlign: align,
          style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: color ?? kCrmText),
        ),
      );

  TableRow _line(RawMaterialRequestRecord r, RawMaterialItem? i, {required int group, required bool first}) {
    final id = '${r.requestNumber}-${i?.material ?? 'none'}';
    return TableRow(
      key: ValueKey('line-$id'),
      decoration: BoxDecoration(
        color: group.isEven ? kCrmSurface : kCrmBg,
        // Séparation marquée entre deux demandes.
        border: first && group > 0
            ? Border(top: BorderSide(color: kRawMaterialHeaderColor.withValues(alpha: 0.45), width: 1.4))
            : null,
      ),
      children: [
        first
            ? IconButton(
                key: ValueKey('detail-${r.requestNumber}'),
                tooltip: _t('Détail'),
                icon: const Icon(Icons.open_in_new_rounded, size: 20, color: kRawMaterialHeaderColor),
                onPressed: () => _openDetail(r),
              )
            : const SizedBox.shrink(),
        _cell(r.requestNumber, key: first ? ValueKey('row-${r.requestNumber}') : null, bold: true),
        _cell(_dateTime(r.createdAt)),
        _cell(r.userEmail, align: TextAlign.left),
        _cell(_t(rawMaterialPosteLabel(r.poste))),
        _cell(_day(r.productionDate)),
        _cell(i?.label ?? '—', key: ValueKey('material-$id'), bold: true),
        _cell(i?.reference ?? '—', key: ValueKey('reference-$id')),
        _cell(i?.lot ?? '—', key: ValueKey('lot-$id')),
        _cell(_qty(i?.quantiteDisponible), key: ValueKey('dispo-$id')),
        _cell(_qty(i?.besoinProduction), key: ValueKey('besoin-$id')),
        _cell(_qty(i?.quantiteDemandee), key: ValueKey('demandee-$id'), bold: true),
        // Saisie par le shift soir ; « — » tant qu'elle n'existe pas.
        _cell(_qty(i == null ? null : r.actualQuantities?[i.material]), key: ValueKey('reelle-$id')),
        _cell(i?.unite ?? '—', key: ValueKey('unite-$id')),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            RawMaterialStatusChip(r.status),
            if (r.overdue) RawMaterialDeadlineChip(overdue: true, key: first ? ValueKey('overdue-${r.requestNumber}') : null),
            if (r.dueSoon) RawMaterialDeadlineChip(overdue: false, key: first ? ValueKey('due-soon-${r.requestNumber}') : null),
          ]),
        ),
        _cell(_dateTime(r.validatedAt)),
      ],
    );
  }

  Widget _pagination() {
    final f = _filters;
    final start = (f.page - 1) * f.pageSize + 1;
    final end = (start + _items.length - 1).clamp(start, _total);
    final hasNext = f.page * f.pageSize < _total;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Expanded(
          child: Text('$start–$end ${_t('sur')} $_total ${_t(_total > 1 ? 'demandes' : 'demande')}',
              key: const ValueKey('raw-material-pagination'), style: const TextStyle(fontSize: 13, color: kCrmTextSub)),
        ),
        IconButton(
          tooltip: _t('Page précédente'),
          onPressed: f.page > 1 && !_loading ? () => _goToPage(f.page - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          tooltip: _t('Page suivante'),
          onPressed: hasNext && !_loading ? () => _goToPage(f.page + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ]),
    );
  }
}

// ── Fiche détaillée ─────────────────────────────────────────────────────────

class RawMaterialRequestDetailDialog extends StatefulWidget {
  final String requestId;
  final RawMaterialTrackingApi api;
  final RawMaterialPermissions permissions;

  const RawMaterialRequestDetailDialog({super.key, required this.requestId, required this.api, required this.permissions});

  @override
  State<RawMaterialRequestDetailDialog> createState() => _RawMaterialRequestDetailDialogState();
}

class _RawMaterialRequestDetailDialogState extends State<RawMaterialRequestDetailDialog> {
  RawMaterialRequestRecord? _r;
  String? _loadError;
  String? _actionError;
  bool _busy = false;
  bool _changed = false;
  final _comment = TextEditingController();

  String _t(String key) => rmT(context, key);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final r = await widget.api.detail(widget.requestId);
      if (mounted) setState(() => _r = r);
    } catch (e) {
      if (mounted) setState(() => _loadError = RawMaterialRequestService.friendlyError(e));
    }
  }

  // N'affiche le nouveau statut qu'une fois confirmé par le backend.
  Future<void> _changeTo(String status) async {
    if (status == 'REJECTED' && _comment.text.trim().isEmpty) {
      setState(() => _actionError = _t('Le motif du rejet est obligatoire.'));
      return;
    }
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final r = await widget.api.changeStatus(widget.requestId, status: status, comment: _comment.text, expectedStatus: _r?.status);
      if (!mounted) return;
      setState(() {
        _r = r;
        _changed = true;
        _comment.clear();
      });
    } catch (e) {
      if (mounted) setState(() => _actionError = RawMaterialRequestService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Shift soir : quantités réelles et acceptation / refus de cette demande.
  Future<void> _eveningHandle() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RawMaterialEveningDialog(api: widget.api, requestId: widget.requestId),
    );
    if (changed == true && mounted) {
      _changed = true;
      await _fetch();
    }
  }

  // Demandeur : corrige sa demande rejetée dans le même formulaire (valeurs
  // rechargées), qui repasse « En attente de validation ».
  Future<void> _resubmit(RawMaterialRequestRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RawMaterialRequestDialog(
        poste: r.poste,
        deadlineAt: r.deadlineAt,
        deadlinePassed: r.deadlineAt != null && DateTime.now().isAfter(r.deadlineAt!),
        rejection: RawMaterialRejection(id: r.id, items: [for (final i in r.items) i.toJson()], comment: r.rejectionComment),
        submit: (_, lines) => widget.api.resubmit(r.id, lines),
      ),
    );
    if (ok == true && mounted) {
      _changed = true;
      await _fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Toute fermeture (bouton, clic à l'extérieur, retour) renvoie `_changed`
    // pour que la liste se recharge après un changement de statut.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) Navigator.of(context).pop(_changed);
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: kCrmSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 980, maxHeight: size.height * 0.92),
          child: _r == null
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: _loadError == null
                      ? const Center(heightFactor: 2, child: CircularProgressIndicator())
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('${_t('Chargement impossible')} : $_loadError', style: const TextStyle(color: kCrmDanger)),
                          const SizedBox(height: 12),
                          TextButton(onPressed: () => Navigator.of(context).pop(_changed), child: Text(_t('Fermer'))),
                        ]),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _header(_r!),
                    const Divider(height: 28, color: kCrmBorder),
                    _info(_r!),
                    const SizedBox(height: 18),
                    _sectionTitle(Icons.inventory_2_outlined, 'Détail des matières'),
                    const SizedBox(height: 8),
                    RawMaterialItemsTable(items: _r!.items, actualQuantities: _r!.actualQuantities),
                    if ((_r!.eveningRefusalComment ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('${_t('Motif du refus (shift soir)')} : « ${_r!.eveningRefusalComment} »',
                          key: const ValueKey('evening-refusal-comment'),
                          style: const TextStyle(color: kCrmDanger, fontWeight: FontWeight.w600)),
                    ],
                    if (_r!.canEveningHandle) ...[
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          key: const ValueKey('evening-handle'),
                          style: FilledButton.styleFrom(backgroundColor: kRawMaterialEveningColor),
                          onPressed: _busy ? null : _eveningHandle,
                          icon: const Icon(Icons.nightlight_round),
                          label: Text(_t('Prendre en charge (shift soir)')),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _sectionTitle(Icons.history_rounded, 'Historique des statuts'),
                    const SizedBox(height: 8),
                    _history(_r!),
                    if ((_r!.rejectionComment ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('${_t('Motif du rejet')} : « ${_r!.rejectionComment} »',
                          key: const ValueKey('rejection-comment'),
                          style: const TextStyle(color: kCrmDanger, fontWeight: FontWeight.w600)),
                    ],
                    if (widget.permissions.nextStatuses(_r!.status).isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _actions(_r!),
                    ],
                    if (_r!.canResubmit) ...[
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          key: const ValueKey('resubmit'),
                          onPressed: _busy ? null : () => _resubmit(_r!),
                          icon: const Icon(Icons.edit_note_rounded),
                          label: Text(_t('Corriger et soumettre à nouveau')),
                        ),
                      ),
                    ],
                  ]),
                ),
        ),
      ),
    );
  }

  Widget _header(RawMaterialRequestRecord r) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: kRawMaterialHeaderColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.inventory_2_outlined, color: kRawMaterialHeaderColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_t('Demande')} ${r.requestNumber}',
                key: const ValueKey('detail-title'),
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kCrmText)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              RawMaterialStatusChip(r.status, key: const ValueKey('detail-status')),
              if (r.overdue) const RawMaterialDeadlineChip(overdue: true),
              if (r.dueSoon) const RawMaterialDeadlineChip(overdue: false),
            ]),
          ]),
        ),
        IconButton(
          tooltip: _t('Fermer'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(_changed),
          icon: const Icon(Icons.close_rounded, color: kCrmTextSub),
        ),
      ]);

  Widget _info(RawMaterialRequestRecord r) {
    final entries = [
      ('Demandeur', r.userEmail),
      ('Date et heure de la demande', _dateTime(r.createdAt)),
      ('Poste', _t(rawMaterialPosteLabel(r.poste))),
      ('Date de production', _day(r.productionDate)),
      if (r.deadlineAt != null) ('Validation requise avant', _dateTime(r.deadlineAt)),
      ('Date et heure de validation',
          r.validatedAt == null ? '—' : '${_dateTime(r.validatedAt)}${r.validatedByEmail == null ? '' : ' — ${r.validatedByEmail}'}'),
      if (r.rejectedAt != null)
        ('Date et heure du rejet', '${_dateTime(r.rejectedAt)}${r.rejectedByEmail == null ? '' : ' — ${r.rejectedByEmail}'}'),
      if (r.eveningHandledAt != null)
        (r.status == 'EVENING_REFUSED' ? 'Refusée par le shift soir le' : 'Prise en charge par le shift soir le',
            '${_dateTime(r.eveningHandledAt)}${r.eveningHandledByEmail == null ? '' : ' — ${r.eveningHandledByEmail}'}'),
    ];
    return Wrap(spacing: 28, runSpacing: 12, children: [
      for (final (label, value) in entries)
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(_t(label), style: const TextStyle(fontSize: 11.5, color: kCrmTextSub, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, color: kCrmText, fontWeight: FontWeight.w600)),
        ]),
    ]);
  }

  Widget _sectionTitle(IconData icon, String key) => Row(children: [
        Icon(icon, size: 18, color: kRawMaterialHeaderColor),
        const SizedBox(width: 8),
        Text(_t(key), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kRawMaterialHeaderColor)),
      ]);

  Widget _history(RawMaterialRequestRecord r) {
    if (r.history.isEmpty) return Text(_t('Aucun historique.'), style: const TextStyle(color: kCrmTextSub));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (i, h) in r.history.indexed)
        Container(
          key: ValueKey('history-$i'),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (h.fromStatus == null)
                Text(_t('Création'), style: const TextStyle(fontWeight: FontWeight.w700, color: kCrmTextSub))
              else
                RawMaterialStatusChip(h.fromStatus!),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: kCrmTextSub),
              RawMaterialStatusChip(h.toStatus),
              Text('${_dateTime(h.createdAt)} — ${h.changedByEmail ?? '—'}', style: const TextStyle(fontSize: 12.5, color: kCrmTextSub)),
            ]),
            if ((h.comment ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('« ${h.comment} »', style: const TextStyle(fontSize: 13, color: kCrmText, fontStyle: FontStyle.italic)),
            ],
          ]),
        ),
    ]);
  }

  Widget _actions(RawMaterialRequestRecord r) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kCrmBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sectionTitle(
            _awaitingDecision(r.status) ? Icons.fact_check_outlined : Icons.sync_alt_rounded,
            _awaitingDecision(r.status) ? 'Validation de la demande' : 'Changer le statut',
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('status-comment'),
            controller: _comment,
            enabled: !_busy,
            maxLength: 1000,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: _t('Commentaire (obligatoire en cas de rejet)'),
              isDense: true,
              filled: true,
              fillColor: kCrmSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (_actionError != null) ...[
            Text(_actionError!, key: const ValueKey('status-error'), style: const TextStyle(color: kCrmDanger, fontSize: 13)),
            const SizedBox(height: 8),
          ],
          Wrap(spacing: 10, runSpacing: 8, children: [
            for (final s in widget.permissions.nextStatuses(r.status))
              FilledButton(
                key: ValueKey('to-$s'),
                onPressed: _busy ? null : () => _changeTo(s),
                style: FilledButton.styleFrom(backgroundColor: rawMaterialStatusColor(s)),
                child: Text(_awaitingDecision(r.status)
                    ? _t(s == 'VALIDATED' ? 'Valider' : 'Rejeter')
                    : '${_t('Passer à')} « ${_t(rawMaterialStatusLabel(s))} »'),
              ),
          ]),
        ]),
      );
}

// Demandes sans décision : En attente de validation, ou Soumise (avant la
// validation obligatoire) — boutons « Valider » / « Rejeter ».
bool _awaitingDecision(String status) => status == 'PENDING_VALIDATION' || status == 'SUBMITTED';

/// « En retard » (échéance vendredi 14 h dépassée) / « Échéance proche ».
class RawMaterialDeadlineChip extends StatelessWidget {
  final bool overdue;
  const RawMaterialDeadlineChip({super.key, required this.overdue});

  @override
  Widget build(BuildContext context) {
    final color = overdue ? kCrmDanger : kCrmWarning;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(overdue ? Icons.alarm_rounded : Icons.schedule_rounded, size: 13, color: Colors.white),
        const SizedBox(width: 4),
        Flexible(
          child: Text(rmT(context, overdue ? 'En retard' : 'Échéance proche'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ]),
    );
  }
}

/// Matières d'une demande (lecture seule) — même présentation que le
/// formulaire : en-têtes bleu foncé, bordures fines, unité KG.
class RawMaterialItemsTable extends StatelessWidget {
  final List<RawMaterialItem> items;

  /// Quantités réelles du shift soir (lecture seule) — colonne « Quantité
  /// réelle (KG) » affichée seulement si fournie.
  final Map<String, double?>? actualQuantities;

  /// Saisie des quantités réelles (shift soir) : champ par matière.
  final Widget Function(RawMaterialItem item)? actualField;

  const RawMaterialItemsTable({super.key, required this.items, this.actualQuantities, this.actualField});

  static const _cols = [
    ('Matière', 140.0),
    ('Référence', 140.0),
    ('Lot', 120.0),
    ('Quantité disponible', 130.0),
    ('Besoin production', 130.0),
    ('Quantité demandée', 130.0),
    ('Unité', 70.0),
  ];

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: _kGrid, width: 0.8);
    final withActual = actualQuantities != null || actualField != null;
    final cols = [
      ..._cols.take(6),
      if (withActual) ('Quantité réelle (KG)', actualField != null ? 150.0 : 130.0),
      _cols.last,
    ];
    Widget cell(String text, {bool header = false, bool bold = false, Key? key}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text(
            text,
            key: key,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: header ? Colors.white : kCrmText,
              fontWeight: header || bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        key: const ValueKey('detail-items-table'),
        border: TableBorder.all(color: side.color, width: side.width),
        columnWidths: {for (var i = 0; i < cols.length; i++) i: FixedColumnWidth(cols[i].$2)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: const BoxDecoration(color: kRawMaterialHeaderColor),
            children: [for (final (label, _) in cols) cell(rmT(context, label), header: true)],
          ),
          for (final i in items)
            TableRow(children: [
              cell(i.label, bold: true),
              cell(i.reference ?? '—'),
              cell(i.lot ?? '—'),
              cell(_qty(i.quantiteDisponible)),
              cell(_qty(i.besoinProduction)),
              cell(_qty(i.quantiteDemandee)),
              if (actualField != null)
                Padding(padding: const EdgeInsets.all(4), child: actualField!(i))
              else if (actualQuantities != null)
                cell(_qty(actualQuantities![i.material]), bold: true, key: ValueKey('actual-${i.material}')),
              cell(i.unite, bold: true),
            ]),
        ],
      ),
    );
  }
}
