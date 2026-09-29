// lib/quality_control/view/quality_control_screen.dart
//
// PRODUCTION / CONTRÔLE QUALITÉ — checklist de production.
//
// Sans `controlId` : choix de la fiche PROMESH/PROBAR à contrôler (liste
// existante GET /production-records, lecture seule) puis création du
// contrôle. Avec `controlId` : checklist des 15 paramètres (valeur / statut /
// remarque), validation, et journal de traçabilité.
//
// Date, heure et contrôleur sont TOUJOURS posés par le serveur (heure de
// Tunisie) — aucun champ de saisie date/heure ici.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/production_records/model/production_record_model.dart';
import 'package:dash_master_toolkit/production_records/service/production_records_service.dart';
import 'package:dash_master_toolkit/reports/view/report_widgets.dart';
import 'package:dash_master_toolkit/route/my_route.dart';
import '../model/quality_control_model.dart';
import '../service/quality_control_service.dart';
import 'quality_control_widgets.dart';

String _fmtIsoDate(String? v) {
  final d = DateTime.tryParse(v ?? '');
  return d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);
}

void _snack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: error ? kCrmDanger : null),
  );
}

class QualityControlScreen extends StatelessWidget {
  final String? controlId;
  const QualityControlScreen({super.key, this.controlId});

  @override
  Widget build(BuildContext context) {
    final id = controlId;
    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: id == null || id.isEmpty ? const _FichePicker() : _ChecklistView(controlId: id),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 1) Choix de la fiche de production
// ═══════════════════════════════════════════════════════════════════════

class _FichePicker extends StatefulWidget {
  const _FichePicker();

  @override
  State<_FichePicker> createState() => _FichePickerState();
}

class _FichePickerState extends State<_FichePicker> {
  final _searchCtrl = TextEditingController();
  String _type = 'all';
  int _page = 1;
  bool _loading = true;
  String? _error;
  String? _creatingRef;
  ProductionRecordPage _data = const ProductionRecordPage();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ProductionRecordsService.instance.fetchPage(
        type: _type,
        search: _searchCtrl.text.trim(),
        page: _page,
        limit: 15,
      );
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startControl(ProductionRecordModel fiche) async {
    setState(() => _creatingRef = fiche.id);
    try {
      final control = await QualityControlService.instance.create(productionRecordRef: fiche.id);
      if (mounted) context.go('${MyRoute.qualityControlFormScreen}?id=${control.id}');
    } catch (e) {
      if (mounted) _snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _creatingRef = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pagination = _data.pagination;
    return IndustrialPageBody(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(children: [
            IconButton(
              tooltip: 'Historique',
              onPressed: () => context.go(MyRoute.qualityControlHistoryScreen),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text('Nouveau contrôle qualité', style: tInter(fontSize: 22, fontWeight: FontWeight.w900, color: kCrmText)),
            ),
          ]),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Text('Sélectionnez la fiche de production à contrôler', style: tInter(fontSize: 12.5, color: kCrmTextSub)),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final t in const ['all', 'promesh', 'probar'])
              ChoiceChip(
                label: Text(t == 'all' ? 'Toutes' : t.toUpperCase()),
                selected: _type == t,
                onSelected: (_) {
                  setState(() {
                    _type = t;
                    _page = 1;
                  });
                  _load();
                },
              ),
            SizedBox(
              width: 280,
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Rechercher (machine, opérateur, date...)',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  _page = 1;
                  _load();
                },
              ),
            ),
          ]),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Text('Erreur : $_error', style: tInter(color: kCrmDanger))
          else if (_data.items.isEmpty)
            const RpEmpty('Aucune fiche de production trouvée')
          else ...[
            for (final f in _data.items) _ficheCard(f),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                onPressed: _page > 1
                    ? () {
                        _page--;
                        _load();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text('Page ${pagination.page} / ${pagination.totalPages}', style: tInter(fontSize: 12.5, color: kCrmTextSub)),
              IconButton(
                onPressed: _page < pagination.totalPages
                    ? () {
                        _page++;
                        _load();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _ficheCard(ProductionRecordModel f) {
    final color = productionTypeColor(f.type);
    final busy = _creatingRef == f.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCrmSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCrmBorder),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.factory_outlined, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.numero ?? f.type.toUpperCase(), style: tInter(fontSize: 14, fontWeight: FontWeight.w800, color: kCrmText)),
            const SizedBox(height: 2),
            Text(
              [
                f.type.toUpperCase(),
                if (f.machine != null) 'Machine ${f.machine}',
                if (f.poste != null) f.poste == 'matin' ? 'Poste Matin' : 'Poste Nuit',
                _fmtIsoDate(f.date),
                if (f.operateur != null && f.operateur!.isNotEmpty) f.operateur!,
              ].join(' · '),
              style: tInter(fontSize: 12.5, color: kCrmTextSub),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _creatingRef == null ? () => _startControl(f) : null,
          icon: busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.fact_check_outlined, size: 18),
          label: const Text('Contrôler'),
          style: ElevatedButton.styleFrom(backgroundColor: kQualityControlColor, foregroundColor: Colors.white, elevation: 0),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 2) Checklist
// ═══════════════════════════════════════════════════════════════════════

class _ChecklistView extends StatefulWidget {
  final String controlId;
  const _ChecklistView({required this.controlId});

  @override
  State<_ChecklistView> createState() => _ChecklistViewState();
}

class _ChecklistViewState extends State<_ChecklistView> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  QualityControlModel? _control;

  final Map<String, TextEditingController> _valueCtrls = {};
  final Map<String, TextEditingController> _remarkCtrls = {};
  final Map<String, String> _statuses = {};
  final _generalRemarkCtrl = TextEditingController();
  String _requestedResult = 'CONFORME';
  Set<String> _serverErrorKeys = {};
  List<String> _serverErrors = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [..._valueCtrls.values, ..._remarkCtrls.values]) {
      c.dispose();
    }
    _generalRemarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _applyControl(await QualityControlService.instance.fetchById(widget.controlId));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyControl(QualityControlModel c) {
    for (final item in c.items) {
      (_valueCtrls[item.parameterKey] ??= TextEditingController()).text = item.value ?? '';
      (_remarkCtrls[item.parameterKey] ??= TextEditingController()).text = item.remark ?? '';
      _statuses[item.parameterKey] = item.status;
    }
    _generalRemarkCtrl.text = c.remark ?? '';
    _requestedResult = c.status == 'NON_CONFORME' ? 'NON_CONFORME' : 'CONFORME';
    if (mounted) {
      setState(() {
        _control = c;
        _serverErrorKeys = {};
        _serverErrors = [];
      });
    }
  }

  bool get _anyNonConforme => _statuses.values.contains('NON_CONFORME');

  List<Map<String, dynamic>> _itemsPayload() => [
        for (final item in _control!.items)
          {
            'parameterKey': item.parameterKey,
            'value': _valueCtrls[item.parameterKey]!.text.trim(),
            'status': _statuses[item.parameterKey],
            'remark': _remarkCtrls[item.parameterKey]!.text.trim(),
          },
      ];

  bool get _hasChanges {
    final c = _control!;
    for (final item in c.items) {
      if (_valueCtrls[item.parameterKey]!.text.trim() != (item.value ?? '')) return true;
      if (_remarkCtrls[item.parameterKey]!.text.trim() != (item.remark ?? '')) return true;
      if (_statuses[item.parameterKey] != item.status) return true;
    }
    if (_generalRemarkCtrl.text.trim() != (c.remark ?? '')) return true;
    if (c.isValidated && !_anyNonConforme && _requestedResult != c.status) return true;
    return false;
  }

  // Mêmes règles que le backend (collectValidationErrors) — affichées avant
  // l'envoi ; le serveur reste l'autorité.
  String? _itemError(QualityControlItem item) {
    final status = _statuses[item.parameterKey];
    final value = _valueCtrls[item.parameterKey]!.text.trim();
    final remark = _remarkCtrls[item.parameterKey]!.text.trim();
    if (status != 'NON_CONTROLE' && value.isEmpty) return 'Valeur obligatoire';
    if (status == 'NON_CONFORME' && remark.isEmpty) return 'Remarque obligatoire pour expliquer l\'anomalie';
    if (!item.autoTime && status == 'NON_CONTROLE' && value.isNotEmpty) return 'Indiquer Conforme ou Non conforme';
    return null;
  }

  List<String> _clientErrors() {
    final errors = <String>[];
    if (!_statuses.values.any((s) => s != 'NON_CONTROLE')) {
      errors.add('Au moins un paramètre doit être contrôlé (Conforme ou Non conforme).');
    }
    for (final item in _control!.items) {
      final e = _itemError(item);
      if (e != null) errors.add('${item.parameterName} : $e');
    }
    if (_requestedResult == 'NON_CONFORME' && !_anyNonConforme && _generalRemarkCtrl.text.trim().isEmpty) {
      errors.add('Remarque générale obligatoire pour un contrôle NON CONFORME sans paramètre non conforme.');
    }
    return errors;
  }

  void _handleError(Object e) {
    if (e is QualityControlApiException && e.errors.isNotEmpty) {
      setState(() {
        _serverErrorKeys = e.parameterKeysInError;
        _serverErrors = e.errors.map((m) => m['message'].toString()).toList();
      });
    }
    _snack(context, e.toString(), error: true);
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    try {
      _applyControl(await QualityControlService.instance.update(
        widget.controlId,
        items: _itemsPayload(),
        remark: _generalRemarkCtrl.text.trim(),
      ));
      if (mounted) _snack(context, 'Contrôle enregistré');
    } catch (e) {
      if (mounted) _handleError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _validate() async {
    final errors = _clientErrors();
    if (errors.isNotEmpty) {
      setState(() => _serverErrors = errors);
      _snack(context, 'Champs obligatoires manquants', error: true);
      return;
    }
    final result = _anyNonConforme ? 'NON_CONFORME' : _requestedResult;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Valider le contrôle qualité'),
        content: Text(
          'Résultat : ${kControlStatusLabels[result]}\n\n'
          'La date, l\'heure et le contrôleur seront enregistrés automatiquement au moment de la validation.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Valider')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final control = await QualityControlService.instance.validate(
        widget.controlId,
        items: _itemsPayload(),
        remark: _generalRemarkCtrl.text.trim(),
        status: result,
      );
      _applyControl(control);
      if (mounted) {
        final notified = control.notificationsSent;
        _snack(
          context,
          'Contrôle validé : ${kControlStatusLabels[control.status]}'
          '${notified != null && notified > 0 ? ' — $notified responsable(s) notifié(s)' : ''}',
        );
      }
    } catch (e) {
      if (mounted) _handleError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Contrôle déjà validé : toute modification exige un motif (backend :
  // CHANGE_REASON_REQUIRED) et reste tracée dans l'historique.
  Future<void> _saveValidatedChanges() async {
    if (!_hasChanges) {
      _snack(context, 'Aucune modification à enregistrer');
      return;
    }
    final errors = _clientErrors();
    if (errors.isNotEmpty) {
      setState(() => _serverErrors = errors);
      _snack(context, 'Champs obligatoires manquants', error: true);
      return;
    }
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier un contrôle validé'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Les anciennes valeurs seront conservées dans l\'historique. Indiquez le motif de la modification.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Motif *', border: OutlineInputBorder()),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(reasonCtrl.text.trim());
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    reasonCtrl.dispose();
    if (reason == null || reason.isEmpty) return;

    setState(() => _saving = true);
    try {
      // Le backend reste l'autorité : NC forcé dès qu'un paramètre est NC.
      final control = await QualityControlService.instance.update(
        widget.controlId,
        items: _itemsPayload(),
        remark: _generalRemarkCtrl.text.trim(),
        status: _anyNonConforme ? 'NON_CONFORME' : _requestedResult,
        changeReason: reason,
      );
      _applyControl(control);
      if (mounted) {
        final notified = control.notificationsSent;
        _snack(context, 'Modification enregistrée${notified != null && notified > 0 ? ' — $notified responsable(s) notifié(s)' : ''}');
      }
    } catch (e) {
      if (mounted) _handleError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showFiche() async {
    final c = _control!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Fiche ${c.ficheNumero ?? ''}'),
        content: SizedBox(
          width: 520,
          child: FutureBuilder<Map<String, dynamic>>(
            future: ProductionRecordsService.instance.fetchDetail(c.productionRecordRef),
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
              }
              if (snap.hasError) return Text('Erreur : ${snap.error}', style: const TextStyle(color: kCrmDanger));
              final entries = (snap.data ?? {})
                  .entries
                  .where((e) => e.value != null && e.value is! Map && e.value is! List && e.value.toString().isNotEmpty)
                  .toList();
              return SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const RpNote('Consultation en lecture seule — la fiche de production n\'est jamais modifiée par le contrôle qualité.'),
                  for (final e in entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 170, child: Text(e.key, style: tInter(fontSize: 12, color: kCrmTextSub))),
                        Expanded(child: Text(e.value.toString(), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600))),
                      ]),
                    ),
                ]),
              );
            },
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fermer'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _control == null) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('Erreur : $_error', style: tInter(color: kCrmDanger)));
    }
    final c = _control!;
    return IndustrialPageBody(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(children: [
            IconButton(
              tooltip: 'Historique',
              onPressed: () => context.go(MyRoute.qualityControlHistoryScreen),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(child: Text('Contrôle qualité', style: tInter(fontSize: 22, fontWeight: FontWeight.w900, color: kCrmText))),
            QualityStatusPill(c.status),
          ]),
          const SizedBox(height: 16),
          _header(c),
          const SizedBox(height: 20),
          ReportSection(
            title: 'Checklist de contrôle',
            icon: Icons.checklist_rounded,
            subtitle: '${c.controlledCount} / ${c.totalCount} paramètres contrôlés · ${c.nonConformCount} non conforme(s)',
            children: [
              LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth >= 820 ? _checklistTable() : _checklistCards(),
              ),
            ],
          ),
          _resultSection(c),
          if (_serverErrors.isNotEmpty) _errorsBox(),
          const SizedBox(height: 8),
          _actions(c),
          const SizedBox(height: 24),
          _historySection(c),
        ],
      ),
    );
  }

  Widget _header(QualityControlModel c) {
    Widget field(String label, String value) => SizedBox(
          width: 200,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: tInter(fontSize: 11.5, color: kCrmTextSub, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: tInter(fontSize: 14, fontWeight: FontWeight.w800, color: kCrmText)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCrmSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCrmBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          IndustrialInfoChip(icon: Icons.factory_outlined, label: c.productionType, color: productionTypeColor(c.productionType)),
          if (c.machineLabel != null)
            IndustrialInfoChip(icon: Icons.precision_manufacturing_outlined, label: c.machineLabel!, color: kCrmTextSub),
          if (c.posteLabel != null) IndustrialInfoChip(icon: Icons.schedule_rounded, label: 'Poste ${c.posteLabel}', color: kCrmTextSub),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 16, runSpacing: 14, children: [
          field('Fiche', c.ficheNumero ?? '—'),
          field('Date production', _fmtIsoDate(c.productionDate)),
          field('Contrôleur', c.controllerEmail),
          field(c.isValidated ? 'Date du contrôle' : 'Ouvert le', c.controlDate),
          field(c.isValidated ? 'Heure du contrôle' : 'Heure d\'ouverture', c.controlTime),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(
            child: RpNote('Date, heure et contrôleur enregistrés automatiquement par le serveur (heure de Tunisie).',
                icon: Icons.lock_clock_outlined),
          ),
          TextButton.icon(
            onPressed: _showFiche,
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Voir la fiche'),
          ),
        ]),
      ]),
    );
  }

  InputDecoration _dec(String hint, {bool error = false}) => InputDecoration(
        isDense: true,
        hintText: hint,
        border: const OutlineInputBorder(),
        enabledBorder: error ? const OutlineInputBorder(borderSide: BorderSide(color: kCrmDanger)) : null,
      );

  Widget _statusDropdown(String key) {
    return DropdownButtonFormField<String>(
      value: _statuses[key],
      isExpanded: true,
      isDense: true,
      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
      items: [
        for (final s in kItemStatuses)
          DropdownMenuItem(
            value: s,
            child: Text(kItemStatusLabels[s]!, style: TextStyle(color: qualityStatusColor(s), fontWeight: FontWeight.w700, fontSize: 13)),
          ),
      ],
      onChanged: _saving
          ? null
          : (v) => setState(() {
                _statuses[key] = v ?? 'NON_CONTROLE';
                if (_anyNonConforme) _requestedResult = 'NON_CONFORME';
              }),
    );
  }

  Widget _checklistTable() {
    final items = _control!.items;
    const header = TextStyle(fontWeight: FontWeight.w700, fontSize: 12);
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(1.6),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(2.6),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        const TableRow(children: [
          Padding(padding: EdgeInsets.all(8), child: Text('Paramètre', style: header)),
          Padding(padding: EdgeInsets.all(8), child: Text('Valeur', style: header)),
          Padding(padding: EdgeInsets.all(8), child: Text('Statut', style: header)),
          Padding(padding: EdgeInsets.all(8), child: Text('Remarque', style: header)),
        ]),
        for (final item in items)
          TableRow(
            decoration: BoxDecoration(
              color: _statuses[item.parameterKey] == 'NON_CONFORME' ? kCrmDanger.withOpacity(0.05) : null,
              border: const Border(top: BorderSide(color: kCrmBorder)),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.parameterName, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: kCrmText)),
                  if (_flagged(item))
                    Text(_itemError(item)!, style: tInter(fontSize: 11, color: kCrmDanger)),
                ]),
              ),
              Padding(padding: const EdgeInsets.all(6), child: _valueField(item)),
              Padding(padding: const EdgeInsets.all(6), child: _statusDropdown(item.parameterKey)),
              Padding(padding: const EdgeInsets.all(6), child: _remarkField(item)),
            ],
          ),
      ],
    );
  }

  Widget _checklistCards() {
    return Column(children: [
      for (final item in _control!.items)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _statuses[item.parameterKey] == 'NON_CONFORME' ? kCrmDanger.withOpacity(0.05) : kCrmSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kCrmBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(item.parameterName, style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText)),
            if (_flagged(item))
              Text(_itemError(item)!, style: tInter(fontSize: 11, color: kCrmDanger)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _valueField(item)),
              const SizedBox(width: 8),
              Expanded(child: _statusDropdown(item.parameterKey)),
            ]),
            const SizedBox(height: 8),
            _remarkField(item),
          ]),
        ),
    ]);
  }

  bool _flagged(QualityControlItem item) =>
      _itemError(item) != null && (_serverErrorKeys.contains(item.parameterKey) || _serverErrors.isNotEmpty);

  Widget _valueField(QualityControlItem item) => TextField(
        controller: _valueCtrls[item.parameterKey],
        enabled: !_saving,
        decoration: _dec(item.autoTime ? 'Auto à la validation' : 'Valeur', error: _flagged(item)),
        onChanged: (_) => setState(() {}),
      );

  Widget _remarkField(QualityControlItem item) => TextField(
        controller: _remarkCtrls[item.parameterKey],
        enabled: !_saving,
        minLines: 1,
        maxLines: 3,
        decoration: _dec(
          _statuses[item.parameterKey] == 'NON_CONFORME' ? 'Expliquer l\'anomalie *' : 'Remarque',
          error: _flagged(item) && _statuses[item.parameterKey] == 'NON_CONFORME',
        ),
        onChanged: (_) => setState(() {}),
      );

  Widget _resultSection(QualityControlModel c) {
    return ReportSection(
      title: 'Résultat du contrôle',
      icon: Icons.verified_outlined,
      subtitle: _anyNonConforme ? 'Un paramètre non conforme impose le résultat NON CONFORME' : null,
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in const ['CONFORME', 'NON_CONFORME'])
            ChoiceChip(
              label: Text(kControlStatusLabels[r]!),
              selected: (_anyNonConforme ? 'NON_CONFORME' : _requestedResult) == r,
              selectedColor: qualityStatusColor(r).withOpacity(0.18),
              onSelected: (_anyNonConforme && r == 'CONFORME') || _saving ? null : (_) => setState(() => _requestedResult = r),
            ),
        ]),
        if (c.nonConformParameters.isNotEmpty || _anyNonConforme) ...[
          const SizedBox(height: 10),
          Text(
            'Paramètre(s) non conforme(s) : ${[
              for (final item in c.items)
                if (_statuses[item.parameterKey] == 'NON_CONFORME') item.parameterName
            ].join(', ')}',
            style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmDanger),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _generalRemarkCtrl,
          enabled: !_saving,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Remarque générale', border: OutlineInputBorder()),
        ),
      ],
    );
  }

  Widget _errorsBox() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kCrmDanger.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kCrmDanger.withOpacity(0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final e in _serverErrors) Text('• $e', style: tInter(fontSize: 12.5, color: kCrmDanger)),
        ]),
      );

  Widget _actions(QualityControlModel c) {
    if (c.isValidated) {
      return Align(
        alignment: Alignment.centerRight,
        child: IndustrialBigButton(
          label: 'Enregistrer les modifications',
          icon: Icons.edit_note_rounded,
          color: kQualityControlColor,
          outlined: true,
          onTap: _saving ? null : _saveValidatedChanges,
        ),
      );
    }
    return Wrap(alignment: WrapAlignment.end, spacing: 12, runSpacing: 12, children: [
      IndustrialBigButton(
        label: 'Enregistrer',
        icon: Icons.save_outlined,
        color: kQualityControlColor,
        outlined: true,
        onTap: _saving ? null : _saveDraft,
      ),
      IndustrialBigButton(
        label: 'Valider le contrôle qualité',
        icon: Icons.verified_rounded,
        color: kQualityControlColor,
        onTap: _saving ? null : _validate,
      ),
    ]);
  }

  static const _actionLabels = {
    'CREATE': 'Création',
    'UPDATE': 'Modification',
    'VALIDATE': 'Validation',
    'STATUS_CHANGE': 'Changement de statut',
    'DELETE': 'Suppression',
  };
  static const _fieldLabels = {'value': 'Valeur', 'status': 'Statut', 'remark': 'Remarque'};

  String _display(String? field, String? v) {
    if (v == null || v.isEmpty) return '∅';
    if (field == 'status') return kItemStatusLabels[v] ?? kControlStatusLabels[v] ?? v;
    return v;
  }

  Widget _historySection(QualityControlModel c) {
    return ReportSection(
      title: 'Traçabilité',
      icon: Icons.history_rounded,
      subtitle: '${c.history.length} événement(s) — ancienne et nouvelle valeur conservées',
      children: [
        if (c.history.isEmpty)
          const RpEmpty('Aucun événement')
        else
          for (final h in c.history.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 130,
                  child: Text('${h.changedDate}\n${h.changedTime}', style: tInter(fontSize: 11.5, color: kCrmTextSub)),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      [
                        _actionLabels[h.action] ?? h.action,
                        if (h.parameterName != null) h.parameterName!,
                        if (h.field != null && h.action == 'UPDATE') _fieldLabels[h.field] ?? h.field!,
                      ].join(' · '),
                      style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText),
                    ),
                    if (h.action == 'UPDATE' || h.action == 'STATUS_CHANGE')
                      Text('${_display(h.field, h.oldValue)} → ${_display(h.field, h.newValue)}',
                          style: tInter(fontSize: 12.5, color: kCrmText)),
                    if (h.reason != null) Text('Motif : ${h.reason}', style: tInter(fontSize: 12, color: kCrmWarning)),
                    Text(h.userEmail ?? '—', style: tInter(fontSize: 11.5, color: kCrmTextSub)),
                  ]),
                ),
              ]),
            ),
      ],
    );
  }
}
