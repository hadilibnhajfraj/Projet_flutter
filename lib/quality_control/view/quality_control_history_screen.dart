// lib/quality_control/view/quality_control_history_screen.dart
//
// Contrôle Qualité — Historique des contrôles qualité : recherche (référence, ligne,
// contrôleur, « machine N » — debounce), filtres production / machine /
// statut / période, pagination SERVEUR (GET /quality-control?page=&limit=).
// Pour le rôle controle_qualite, le backend limite déjà la liste à ses
// propres contrôles (admins : tous). `?q=` : recherche globale de l'en-tête.

import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import '../model/quality_control_comparison.dart';
import '../model/quality_control_model.dart';
import '../quality_control_routes.dart';
import '../service/quality_control_service.dart';
import 'quality_control_export.dart';
import 'quality_control_widgets.dart';
import '../quality_control_i18n.dart';

// Filtre statut → valeur(s) backend. "À vérifier" = contrôle non validé.
const _kStatusFilters = <(String, String)>[
  ('', 'Tous'),
  ('EN_ATTENTE,EN_COURS', 'À vérifier'),
  ('CONFORME', 'Conforme'),
  ('NON_CONFORME', 'Non conforme'),
];

class QualityControlHistoryScreen extends StatefulWidget {
  final String? initialQuery;
  const QualityControlHistoryScreen({super.key, this.initialQuery});

  @override
  State<QualityControlHistoryScreen> createState() => _QualityControlHistoryScreenState();
}

class _QualityControlHistoryScreenState extends State<QualityControlHistoryScreen> {
  static const _pageSize = 20;
  static const _debounce = Duration(milliseconds: 350);

  final _df = DateFormat('yyyy-MM-dd');
  late final _searchCtrl = TextEditingController(text: widget.initialQuery ?? '');
  Timer? _searchTimer;
  int _requestSeq = 0;

  bool _loading = true;
  bool _exporting = false;
  String? _error;
  QualityControlPage _page = const QualityControlPage();
  QualityConfig _config = const QualityConfig();

  int _pageIndex = 1;
  String _type = '';
  String? _machine;
  String _status = '';
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    QualityControlService.instance.fetchConfig().then((c) {
      if (mounted) setState(() => _config = c);
    }).catchError((_) {});
    _load();
  }

  // Même page (clé "qc-history") rouverte avec une autre recherche globale.
  @override
  void didUpdateWidget(covariant QualityControlHistoryScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialQuery != old.initialQuery) {
      _searchCtrl.text = widget.initialQuery ?? '';
      _reload();
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await QualityControlService.instance.fetchHistoryPage(
        page: _pageIndex,
        limit: _pageSize,
        productionType: _type,
        machine: _machine,
        status: _status,
        from: _from == null ? null : _df.format(_from!),
        to: _to == null ? null : _df.format(_to!),
        search: _searchCtrl.text,
      );
      // Réponse obsolète (filtre modifié entre-temps) : ignorée.
      if (mounted && seq == _requestSeq) setState(() => _page = page);
    } catch (e) {
      if (mounted && seq == _requestSeq) setState(() => _error = e.toString());
    } finally {
      if (mounted && seq == _requestSeq) setState(() => _loading = false);
    }
  }

  void _reload() {
    _pageIndex = 1;
    _load();
  }

  void _onSearchChanged(String _) {
    _searchTimer?.cancel();
    _searchTimer = Timer(_debounce, _reload);
    setState(() {}); // bouton d'effacement
  }

  List<String> get _machines {
    final lines = _type.isEmpty ? _config.productionLines : [if (_config.line(_type) != null) _config.line(_type)!];
    return {for (final l in lines) ...l.machines}.toList()..sort();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _from != null && _to != null ? DateTimeRange(start: _from!, end: _to!) : null,
    );
    if (picked == null) return;
    setState(() {
      _from = picked.start;
      _to = picked.end;
    });
    _reload();
  }

  bool get _hasFilters =>
      _type.isNotEmpty || _machine != null || _status.isNotEmpty || _from != null || _searchCtrl.text.trim().isNotEmpty;

  void _reset() {
    _searchTimer?.cancel();
    setState(() {
      _searchCtrl.clear();
      _type = '';
      _machine = null;
      _status = '';
      _from = null;
      _to = null;
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    return QcPage(
      onRefresh: _load,
      children: [
        QcPageHeader(
          crumbs: const [('Contrôle Qualité', QcPaths.root), ('Historique', null)],
          title: 'Historique des contrôles qualité',
          subtitle: 'Recherchez et filtrez les contrôles qualité PROMESH et PROBAR.',
          icon: Icons.history_rounded,
          onBack: () => context.go(QcPaths.root),
          actions: [
            OutlinedButton.icon(
              onPressed: () => context.go(QcPaths.comparison),
              icon: const Icon(Icons.compare_arrows_rounded, size: 18),
              label: const Text('Comparaison qualité'),
            ),
            QcExportButton(busy: _exporting, onSelected: _export),
          ],
        ),
        _filters(),
        QcSection(
          icon: Icons.fact_check_outlined,
          title: 'Contrôles qualité',
          subtitle: _loading && _page.items.isEmpty ? 'Chargement…' : '${qcFormatInt(_page.total)} contrôle(s) qualité',
          trailing: _loading && _page.items.isNotEmpty
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : null,
          children: [
            if (_error != null)
              QcErrorBanner(_error!, onRetry: _load)
            else
              QcControlsTable(
                controls: _page.items,
                loading: _loading,
                extended: true,
                emptyText: _hasFilters ? 'Aucun contrôle qualité pour ces critères' : 'Aucun contrôle qualité pour le moment',
              ),
            if (_page.totalPages > 1) _pager(),
          ],
        ),
      ],
    );
  }

  /// Filtres ACTUELS de l'écran — exactement ceux de la liste.
  Map<String, String> get _query => QualityControlService.historyQuery(
        productionType: _type,
        machine: _machine,
        status: _status,
        from: _from == null ? null : _df.format(_from!),
        to: _to == null ? null : _df.format(_to!),
        search: _searchCtrl.text,
      );

  // Export des données FILTRÉES (le backend applique les mêmes filtres).
  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    final q = _query;
    await runQcExport(
      context,
      format: format,
      fetch: () => QualityControlService.instance.exportHistory(format, q),
      fileName: qcHistoryExportFileName(productionType: q['productionType'], machine: q['machine'], from: q['from'], to: q['to'], ext: format),
    );
    if (mounted) setState(() => _exporting = false);
  }

  Widget _filters() {
    String fmt(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: kCrmBorder));
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: qcCardDecoration(),
      child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 320,
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            onSubmitted: (_) {
              _searchTimer?.cancel();
              _reload();
            },
            style: tInter(fontSize: 13, color: kCrmText),
            decoration: InputDecoration(
              isDense: true,
              hintText: qcT('Référence, ligne, contrôleur, machine…'),
              hintStyle: tInter(fontSize: 12.5, color: kCrmTextSub),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: qcT('Effacer'),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        _reload();
                      },
                    ),
              filled: true,
              fillColor: kCrmBg,
              border: border,
              enabledBorder: border,
            ),
          ),
        ),
        _segmented<String>(
          value: _type,
          options: [('', 'Toutes'), for (final l in _config.productionLines) (l.type, l.label)],
          colorOf: (v) => v.isEmpty ? kCrmText : productionTypeColor(v),
          onChanged: (v) {
            setState(() {
              _type = v;
              _machine = null;
            });
            _reload();
          },
        ),
        SizedBox(
          width: 190,
          // Clé locale (jamais une GlobalKey) : recrée le champ quand le
          // filtre change par programme (ligne modifiée, réinitialisation).
          child: DropdownButtonFormField<String?>(
            key: ValueKey('qc-history-machine-$_type-$_machine'),
            initialValue: _machine,
            isDense: true,
            isExpanded: true,
            style: tInter(fontSize: 13, color: kCrmText),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(kMachineIcon, size: 18),
              border: border,
              enabledBorder: border,
              filled: true,
              fillColor: kCrmBg,
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Machines', overflow: TextOverflow.ellipsis)),
              for (final m in _machines) DropdownMenuItem<String?>(value: m, child: Text('Machine $m', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              setState(() => _machine = v);
              _reload();
            },
          ),
        ),
        _segmented<String>(
          value: _status,
          options: _kStatusFilters,
          colorOf: (v) => switch (v) {
            'CONFORME' => kQcConformeText,
            'NON_CONFORME' => kQcNonConformeText,
            '' => kCrmText,
            _ => kQcAVerifierText,
          },
          onChanged: (v) {
            setState(() => _status = v);
            _reload();
          },
        ),
        OutlinedButton.icon(
          onPressed: _pickRange,
          style: OutlinedButton.styleFrom(foregroundColor: kCrmText, side: const BorderSide(color: kCrmBorder)),
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(_from == null || _to == null ? 'Période' : '${fmt(_from!)} → ${fmt(_to!)}'),
        ),
        if (_hasFilters)
          TextButton.icon(onPressed: _reset, icon: const Icon(Icons.restart_alt_rounded, size: 18), label: const Text('Réinitialiser')),
      ]),
    );
  }

  Widget _segmented<T>({
    required T value,
    required List<(T, String)> options,
    required Color Function(T v) colorOf,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(9), border: Border.all(color: kCrmBorder)),
      child: Wrap(children: [
        for (final (v, label) in options)
          InkWell(
            onTap: () => onChanged(v),
            borderRadius: BorderRadius.circular(7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: v == value ? kCrmSurface : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                boxShadow: v == value ? const [BoxShadow(color: Color(0x140F172A), blurRadius: 4, offset: Offset(0, 1))] : null,
              ),
              child: Text(label,
                  style: tInter(fontSize: 12, fontWeight: v == value ? FontWeight.w700 : FontWeight.w500, color: v == value ? colorOf(v) : kCrmTextSub)),
            ),
          ),
      ]),
    );
  }

  Widget _pager() => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('Page ${_page.page} / ${_page.totalPages}', style: tInter(fontSize: 12, color: kCrmTextSub)),
          const SizedBox(width: 8),
          IconButton(
            tooltip: qcT('Page précédente'),
            visualDensity: VisualDensity.compact,
            onPressed: _pageIndex > 1 && !_loading
                ? () {
                    _pageIndex--;
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: qcT('Page suivante'),
            visualDensity: VisualDensity.compact,
            onPressed: _pageIndex < _page.totalPages && !_loading
                ? () {
                    _pageIndex++;
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ]),
      );
}
