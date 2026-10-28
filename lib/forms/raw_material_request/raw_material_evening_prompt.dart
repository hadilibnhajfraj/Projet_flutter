// lib/forms/raw_material_request/raw_material_evening_prompt.dart
//
// Shift soir (production_2@cbi-tunisia.com) : prise en charge des demandes
// de matières premières VALIDÉES par le responsable logistique.
//
//   - RawMaterialEveningPrompt : popup à la connexion (AppShell, session et
//     navigation prêtes), une fois par session tant qu'une demande validée
//     attend le shift soir ;
//   - RawMaterialEveningDialog : la demande validée (lecture seule), la
//     colonne « Quantité réelle (KG) » à saisir, « Accepter la demande »
//     (confirmation) et « Refuser la demande » (motif obligatoire). Aussi
//     ouverte depuis la fiche détaillée de la page de suivi.
//
// Données relues depuis le backend ; les quantités demandées ne sont jamais
// modifiées ni recalculées. Le backend revérifie le compte, le statut et les
// valeurs (une seule prise en charge possible).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';

import 'raw_material_request_form.dart' show parseRawMaterialQuantity, rmT, validateRawMaterialQuantity;
import 'raw_material_request_login_prompt.dart';
import 'raw_material_request_record.dart';
import 'raw_material_request_service.dart' show RawMaterialRequestService;
import 'raw_material_requests_screen.dart' show RawMaterialItemsTable, RawMaterialStatusChip;
import 'raw_material_tracking_service.dart';

/// Comptes du shift soir — même liste que le backend
/// (RAW_MATERIAL_REQUEST_EVENING_HANDLERS), qui reste seul juge.
const kRawMaterialEveningEmails = {'production_2@cbi-tunisia.com'};

const kRawMaterialEveningColor = Color(0xFF0D9488);

String _dateTime(DateTime? d) => d == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
String _day(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  return d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);
}

String _qty(double? v) {
  if (v == null) return '—';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ',');
}

class RawMaterialEveningPrompt {
  RawMaterialEveningPrompt._();

  static String? _inFlight;

  @visibleForTesting
  static void resetForTest() => _inFlight = null;

  static Future<void> maybeShow(
    BuildContext context, {
    Future<String?> Function()? loadSessionId,
    Future<String?> Function()? loadEmail,
    RawMaterialTrackingApi? api,
    RawMaterialPromptStore? store,
  }) async {
    final s = store ?? const GetStorageRawMaterialPromptStore('rawMaterialEveningPromptSession');
    final sessionId = await (loadSessionId ?? RawMaterialLoginPrompt.defaultSessionId)();
    if (sessionId == null || _inFlight == sessionId || s.read() == sessionId) return;
    _inFlight = sessionId;
    final a = api ?? RawMaterialTrackingService.instance;
    try {
      final email = normalizeEmail(await (loadEmail ?? RawMaterialLoginPrompt.defaultEmail)());
      if (!kRawMaterialEveningEmails.contains(email)) {
        await s.write(sessionId);
        return;
      }
      // Demandes validées encore à prendre en charge — depuis le backend.
      final r = await a.list(const RawMaterialFilters(status: 'VALIDATED', pageSize: 200));
      if (r.items.where((i) => i.status == 'VALIDATED').isEmpty) {
        await s.write(sessionId);
        return;
      }
      if (!context.mounted) return; // non marqué : réessayé au prochain affichage
      await showDialog<void>(context: context, barrierDismissible: false, builder: (_) => RawMaterialEveningDialog(api: a));
      await s.write(sessionId);
    } catch (e) {
      // Vérification impossible : rien n'est considéré traité ; la page de
      // suivi reste accessible et la popup sera retentée à la prochaine connexion.
      debugPrint('[RawMaterialEveningPrompt] vérification impossible : $e');
    } finally {
      if (_inFlight == sessionId) _inFlight = null;
    }
  }
}

/// Demandes validées à prendre en charge (une à la fois). [requestId] :
/// uniquement cette demande (ouverte depuis la fiche détaillée).
class RawMaterialEveningDialog extends StatefulWidget {
  final RawMaterialTrackingApi api;
  final String? requestId;

  const RawMaterialEveningDialog({super.key, required this.api, this.requestId});

  @override
  State<RawMaterialEveningDialog> createState() => _RawMaterialEveningDialogState();
}

class _RawMaterialEveningDialogState extends State<RawMaterialEveningDialog> {
  final _formKey = GlobalKey<FormState>();
  List<RawMaterialRequestRecord> _items = const [];
  int _index = 0;
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;
  bool _attempted = false;
  String? _loadError;
  String? _success;
  String? _error;
  // Quantités réelles saisies, par demande puis par matière (conservées en cas d'erreur).
  final _actual = <String, Map<String, TextEditingController>>{};

  String _t(String key) => rmT(context, key);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final m in _actual.values) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Map<String, TextEditingController> _controllers(RawMaterialRequestRecord r) => _actual.putIfAbsent(
        r.id,
        () => {for (final i in r.items) i.material: TextEditingController()}, // vide par défaut
      );

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      List<RawMaterialRequestRecord> items;
      if (widget.requestId != null) {
        final r = await widget.api.detail(widget.requestId!);
        items = r.status == 'VALIDATED' ? [r] : const [];
      } else {
        final r = await widget.api.list(const RawMaterialFilters(status: 'VALIDATED', pageSize: 200));
        items = [...r.items.where((i) => i.status == 'VALIDATED')]
          ..sort((a, b) => (a.validatedAt ?? DateTime(0)).compareTo(b.validatedAt ?? DateTime(0)));
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _index = items.isEmpty ? 0 : _index.clamp(0, items.length - 1);
        _attempted = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = RawMaterialRequestService.friendlyError(e);
      });
    }
  }

  RawMaterialRequestRecord get _current => _items[_index];

  Future<void> _accept() async {
    final r = _current;
    setState(() => _attempted = true);
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _error = _t('Saisissez une quantité réelle valide pour chaque matière (0 accepté).'));
      return;
    }
    final c = _controllers(r);
    final actual = {for (final i in r.items) i.material: parseRawMaterialQuantity(c[i.material]!.text)!};
    final ok = await showDialog<bool>(context: context, builder: (_) => _AcceptConfirmDialog(request: r, actual: actual));
    if (ok != true) return;
    await _run(() => widget.api.eveningAccept(r.id, actual), '${_t('Demande')} ${r.requestNumber} ${_t('acceptée par le shift soir.')}');
  }

  Future<void> _refuse() async {
    final r = _current;
    final comment = await showDialog<String>(context: context, builder: (_) => _RefuseDialog(requestNumber: r.requestNumber));
    if (comment == null) return;
    await _run(() => widget.api.eveningRefuse(r.id, comment: comment), '${_t('Demande')} ${r.requestNumber} ${_t('refusée par le shift soir.')}');
  }

  Future<void> _run(Future<Object?> Function() action, String successMessage) async {
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await action();
      if (!mounted) return;
      _changed = true;
      _success = successMessage;
      await _load(); // relu depuis le backend
    } catch (e) {
      // Saisie conservée ; rien n'est considéré enregistré.
      if (mounted) setState(() => _error = '${_t('L\'action n\'a pas pu être enregistrée')} : ${RawMaterialRequestService.friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
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
          constraints: BoxConstraints(maxWidth: 1100, maxHeight: size.height * 0.92),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _header(),
              const Divider(height: 28, color: kCrmBorder),
              if (_success != null) _banner(const ValueKey('evening-success'), Icons.check_circle_rounded, kCrmSuccess, _success!),
              if (_error != null) _banner(const ValueKey('evening-error'), Icons.error_outline_rounded, kCrmDanger, _error!),
              _body(),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: kRawMaterialEveningColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.nightlight_round, color: kRawMaterialEveningColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_t('Demande de matières premières validée — shift soir'),
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kCrmText)),
            const SizedBox(height: 4),
            Text(_t('Vérifiez la demande validée, saisissez les quantités réelles puis acceptez-la ou refusez-la.'),
                style: const TextStyle(fontSize: 13, color: kCrmTextSub)),
          ]),
        ),
        IconButton(
          tooltip: _t('Fermer'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(_changed),
          icon: const Icon(Icons.close_rounded, color: kCrmTextSub),
        ),
      ]);

  Widget _banner(Key key, IconData icon, Color color, String text) => Container(
        key: key,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _body() {
    if (_loading && _items.isEmpty) return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
    if (_loadError != null) {
      return Column(children: [
        Text('${_t('Chargement impossible')} : $_loadError', style: const TextStyle(color: kCrmDanger)),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _load, child: Text(_t('Réessayer'))),
      ]);
    }
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(children: [
          const Icon(Icons.task_alt_rounded, size: 48, color: kCrmSuccess),
          const SizedBox(height: 10),
          Text(_t('Aucune demande validée en attente du shift soir.'),
              key: const ValueKey('evening-empty'), style: const TextStyle(fontWeight: FontWeight.w700, color: kCrmText)),
          const SizedBox(height: 14),
          FilledButton(onPressed: () => Navigator.of(context).pop(_changed), child: Text(_t('Fermer'))),
        ]),
      );
    }
    final r = _current;
    final c = _controllers(r);
    return Form(
      key: _formKey,
      autovalidateMode: _attempted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_items.length > 1)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              key: const ValueKey('evening-prev'),
              tooltip: _t('Demande précédente'),
              onPressed: _busy || _index == 0 ? null : () => setState(() => _index--),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text('${_t('Demande')} ${_index + 1} / ${_items.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
            IconButton(
              key: const ValueKey('evening-next'),
              tooltip: _t('Demande suivante'),
              onPressed: _busy || _index >= _items.length - 1 ? null : () => setState(() => _index++),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ]),
        _info(r),
        const SizedBox(height: 14),
        RawMaterialItemsTable(
          items: r.items,
          actualField: (i) => TextFormField(
            key: ValueKey('actual-input-${i.material}'),
            controller: c[i.material],
            enabled: !_busy,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            validator: (v) {
              final e = validateRawMaterialQuantity(v);
              return e == null ? null : _t(e);
            },
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: kCrmBg,
              suffixText: 'KG',
              errorMaxLines: 2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 8, children: [
          FilledButton.icon(
            key: const ValueKey('evening-refuse'),
            style: FilledButton.styleFrom(backgroundColor: kCrmDanger),
            onPressed: _busy ? null : _refuse,
            icon: const Icon(Icons.close_rounded),
            label: Text(_t('Refuser la demande')),
          ),
          FilledButton.icon(
            key: const ValueKey('evening-accept'),
            style: FilledButton.styleFrom(backgroundColor: kRawMaterialEveningColor),
            onPressed: _busy ? null : _accept,
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded),
            label: Text(_t('Accepter la demande')),
          ),
        ]),
      ]),
    );
  }

  Widget _info(RawMaterialRequestRecord r) {
    final entries = [
      ('N° demande', r.requestNumber),
      ('Date de production', _day(r.productionDate)),
      ('Poste', _t(rawMaterialPosteLabel(r.poste))),
      ('Demandeur', r.userEmail),
      ('Validée par', r.validatedByEmail ?? '—'),
      ('Date et heure de validation', _dateTime(r.validatedAt)),
    ];
    return Container(
      key: ValueKey('evening-card-${r.requestNumber}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kCrmBorder)),
      child: Wrap(spacing: 28, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
        for (final (label, value) in entries)
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(_t(label), style: const TextStyle(fontSize: 11.5, color: kCrmTextSub, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 14, color: kCrmText, fontWeight: FontWeight.w700)),
          ]),
        RawMaterialStatusChip(r.status),
      ]),
    );
  }
}

/// Confirmation : numéro, tableau des matières (demandé / réel), message.
class _AcceptConfirmDialog extends StatelessWidget {
  final RawMaterialRequestRecord request;
  final Map<String, double> actual;
  const _AcceptConfirmDialog({required this.request, required this.actual});

  @override
  Widget build(BuildContext context) {
    String t(String k) => rmT(context, k);
    const head = TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13);
    Widget cell(String s, {TextStyle? style, Key? key}) =>
        Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), child: Text(s, key: key, textAlign: TextAlign.center, style: style));
    return AlertDialog(
      title: Text('${t('Accepter la demande')} ${request.requestNumber}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
              t('Cette demande de matières premières a été validée par le responsable logistique. '
                  'Confirmez-vous sa prise en charge pour le shift soir ?'),
              key: const ValueKey('evening-confirm-message'),
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 14),
            Table(
              key: const ValueKey('evening-confirm-table'),
              border: TableBorder.all(color: const Color(0xFF94A3B8), width: 0.8),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(decoration: const BoxDecoration(color: Color(0xFF1F3A5F)), children: [
                  cell(t('Matière'), style: head),
                  cell(t('Quantité demandée (KG)'), style: head),
                  cell(t('Quantité réelle (KG)'), style: head),
                  cell(t('Unité'), style: head),
                ]),
                for (final i in request.items)
                  TableRow(children: [
                    cell(i.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    cell(_qty(i.quantiteDemandee)),
                    cell(_qty(actual[i.material]), key: ValueKey('confirm-actual-${i.material}'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    cell(i.unite),
                  ]),
              ],
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t('Annuler'))),
        FilledButton(
          key: const ValueKey('evening-confirm-accept'),
          style: FilledButton.styleFrom(backgroundColor: kRawMaterialEveningColor),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(t('Confirmer la prise en charge')),
        ),
      ],
    );
  }
}

/// Refus : motif obligatoire (aussi exigé par le backend).
class _RefuseDialog extends StatefulWidget {
  final String requestNumber;
  const _RefuseDialog({required this.requestNumber});

  @override
  State<_RefuseDialog> createState() => _RefuseDialogState();
}

class _RefuseDialogState extends State<_RefuseDialog> {
  final _comment = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t(String k) => rmT(context, k);
    return AlertDialog(
      title: Text('${t('Refuser la demande')} ${widget.requestNumber}'),
      content: SizedBox(
        width: 460,
        child: TextField(
          key: const ValueKey('evening-refuse-comment'),
          controller: _comment,
          autofocus: true,
          maxLength: 1000,
          maxLines: 3,
          decoration: InputDecoration(labelText: t('Motif du refus (obligatoire)'), errorText: _error, border: const OutlineInputBorder()),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t('Annuler'))),
        FilledButton(
          key: const ValueKey('evening-confirm-refuse'),
          style: FilledButton.styleFrom(backgroundColor: kCrmDanger),
          onPressed: () {
            final text = _comment.text.trim();
            if (text.isEmpty) {
              setState(() => _error = t('Le motif du refus est obligatoire.'));
              return;
            }
            Navigator.of(context).pop(text);
          },
          child: Text(t('Refuser')),
        ),
      ],
    );
  }
}
