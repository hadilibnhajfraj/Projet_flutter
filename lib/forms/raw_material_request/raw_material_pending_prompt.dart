// lib/forms/raw_material_request/raw_material_pending_prompt.dart
//
// Demandes de matières premières À TRAITER par le responsable logistique
// achats (responsables logistique et production) : toutes les demandes sans
// décision — « En attente de validation » et « Soumise » (demandes créées
// avant la validation obligatoire) —, quel que soit le demandeur.
//
//   - RawMaterialPendingPrompt : popup à la connexion (déclenchée par
//     AppShell une fois la session et la navigation prêtes), une fois par
//     session tant qu'il reste des demandes à traiter ;
//   - RawMaterialPendingReview : le contenu (liste relue depuis le backend,
//     Consulter / Valider / Rejeter), partagé par la popup (une demande à la
//     fois) et la page « Demandes à valider » (toutes les demandes).
//
// Tout vient du backend (liste, compteur, décisions) : fermer la popup ne
// change jamais le statut d'une demande. Validation / rejet : mêmes routes,
// mêmes contrôles et même historique que la page de suivi.

import 'package:dash_master_toolkit/core/config/logistics_managers.dart';
import 'package:dash_master_toolkit/services/socket_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';

import 'raw_material_request_form.dart' show rmT;
import 'raw_material_request_login_prompt.dart';
import 'raw_material_request_record.dart';
import 'raw_material_request_service.dart' show RawMaterialRequestService;
import 'raw_material_requests_screen.dart'
    show RawMaterialDeadlineChip, RawMaterialItemsTable, RawMaterialRequestDetailDialog, RawMaterialStatusChip;
import 'raw_material_tracking_service.dart';

/// Comptes qui reçoivent cette popup — même liste que le backend
/// (config/rawMaterialRequest.js, RAW_MATERIAL_REQUEST_VALIDATORS), qui reste
/// seul juge des décisions.
// Responsables logistique et production (liste centrale).
const kRawMaterialValidatorEmails = kLogisticsManagerEmails;

/// Statuts « sans décision » (backend : AWAITING_DECISION_STATUSES).
const kRawMaterialAwaitingStatuses = {'PENDING_VALIDATION', 'SUBMITTED'};

String _dateTime(DateTime? d) => d == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
String _day(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  return d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);
}

class RawMaterialPendingPrompt {
  RawMaterialPendingPrompt._();

  static String? _inFlight;

  @visibleForTesting
  static void resetForTest() => _inFlight = null;

  /// [onCountChanged] : nouveau compteur après la popup (badge du menu).
  static Future<void> maybeShow(
    BuildContext context, {
    Future<String?> Function()? loadSessionId,
    Future<String?> Function()? loadEmail,
    RawMaterialTrackingApi? api,
    RawMaterialPromptStore? store,
    ValueChanged<int>? onCountChanged,
  }) async {
    final s = store ?? const GetStorageRawMaterialPromptStore('rawMaterialPendingPromptSession');
    final sessionId = await (loadSessionId ?? RawMaterialLoginPrompt.defaultSessionId)();
    if (sessionId == null || _inFlight == sessionId || s.read() == sessionId) return;
    _inFlight = sessionId;
    final a = api ?? RawMaterialTrackingService.instance;
    try {
      final email = normalizeEmail(await (loadEmail ?? RawMaterialLoginPrompt.defaultEmail)());
      if (!kRawMaterialValidatorEmails.contains(email)) {
        await s.write(sessionId);
        return;
      }
      // Toujours depuis le backend, jamais depuis un cache local.
      final summary = await a.pendingSummary();
      onCountChanged?.call(summary.pending);
      if (summary.pending == 0) {
        await s.write(sessionId);
        return;
      }
      if (!context.mounted) return; // non marqué : réessayé au prochain affichage
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => RawMaterialPendingDialog(api: a, onCountChanged: onCountChanged),
      );
      await s.write(sessionId);
    } catch (e) {
      // Vérification impossible : rien n'est masqué ni considéré traité ; la
      // page « Demandes à valider » reste accessible et la popup sera
      // retentée à la prochaine connexion.
      debugPrint('[RawMaterialPendingPrompt] vérification impossible : $e');
    } finally {
      if (_inFlight == sessionId) _inFlight = null;
    }
  }
}

class RawMaterialPendingDialog extends StatelessWidget {
  final RawMaterialTrackingApi api;
  final ValueChanged<int>? onCountChanged;

  const RawMaterialPendingDialog({super.key, required this.api, this.onCountChanged});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: kCrmSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1000, maxHeight: size.height * 0.92),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: RawMaterialPendingReview(
            api: api,
            onCountChanged: onCountChanged,
            oneAtATime: true,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}

/// Liste des demandes à traiter et décisions. [oneAtATime] : popup (une
/// demande à la fois, navigation) ; sinon page (toutes les demandes).
class RawMaterialPendingReview extends StatefulWidget {
  final RawMaterialTrackingApi api;
  final ValueChanged<int>? onCountChanged;
  final bool oneAtATime;
  final VoidCallback? onClose;

  const RawMaterialPendingReview({
    super.key,
    required this.api,
    this.onCountChanged,
    this.oneAtATime = false,
    this.onClose,
  });

  @override
  State<RawMaterialPendingReview> createState() => _RawMaterialPendingReviewState();
}

class _RawMaterialPendingReviewState extends State<RawMaterialPendingReview> {
  List<RawMaterialRequestRecord> _items = const [];
  int _total = 0;
  int _index = 0;
  bool _loading = true;
  bool _busy = false;
  String? _loadError;
  String? _success;
  String? _error;

  String _t(String key) => rmT(context, key);

  // Demande validée / rejetée par un autre responsable : liste relue, la
  // demande déjà traitée disparaît (aucune seconde décision possible).
  late final void Function(dynamic) _onRemoteUpdate = (_) {
    if (mounted && !_busy) _load();
  };

  @override
  void initState() {
    super.initState();
    SocketService.instance.on('raw-material-request:updated', _onRemoteUpdate);
    _load();
  }

  @override
  void dispose() {
    SocketService.instance.off('raw-material-request:updated', _onRemoteUpdate);
    super.dispose();
  }

  // Demandes les plus urgentes d'abord : échéance la plus proche (les
  // demandes sans échéance ensuite), puis soumission la plus ancienne.
  static int _byDeadline(RawMaterialRequestRecord a, RawMaterialRequestRecord b) {
    int cmp(DateTime? x, DateTime? y) => x == null ? (y == null ? 0 : 1) : (y == null ? -1 : x.compareTo(y));
    final byDeadline = cmp(a.deadlineAt, b.deadlineAt);
    return byDeadline != 0 ? byDeadline : cmp(a.createdAt, b.createdAt);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final r = await widget.api.list(const RawMaterialFilters(toProcess: true, pageSize: 200));
      if (!mounted) return;
      final items = [...r.items.where((i) => kRawMaterialAwaitingStatuses.contains(i.status))]..sort(_byDeadline);
      setState(() {
        _items = items;
        _total = r.total;
        _index = items.isEmpty ? 0 : _index.clamp(0, items.length - 1);
        _loading = false;
      });
      widget.onCountChanged?.call(r.total);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = RawMaterialRequestService.friendlyError(e);
      });
    }
  }

  Future<void> _decide(RawMaterialRequestRecord r, String status, {String? comment}) async {
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await widget.api.changeStatus(r.id, status: status, comment: comment, expectedStatus: r.status);
      if (!mounted) return;
      _success = '${_t('Demande')} ${r.requestNumber} ${_t(status == 'VALIDATED' ? 'validée.' : 'rejetée.')}';
      await _load(); // statut et compteur relus depuis le backend
    } catch (e) {
      if (mounted) setState(() => _error = '${_t('La décision n\'a pas pu être enregistrée')} : ${RawMaterialRequestService.friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _validate(RawMaterialRequestRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Valider cette demande')),
        content: Text('${_t('Confirmer la validation de la demande')} ${r.requestNumber} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(_t('Annuler'))),
          FilledButton(
            key: const ValueKey('confirm-validate'),
            style: FilledButton.styleFrom(backgroundColor: kCrmSuccess),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(_t('Valider')),
          ),
        ],
      ),
    );
    if (ok == true) await _decide(r, 'VALIDATED');
  }

  Future<void> _reject(RawMaterialRequestRecord r) async {
    final comment = await showDialog<String>(context: context, builder: (_) => _RejectDialog(requestNumber: r.requestNumber));
    if (comment != null) await _decide(r, 'REJECTED', comment: comment);
  }

  Future<void> _details(RawMaterialRequestRecord r) async {
    final perms = await widget.api.permissions();
    if (!mounted) return;
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => RawMaterialRequestDetailDialog(requestId: r.id, api: widget.api, permissions: perms),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(),
        const SizedBox(height: 8),
        Text(
          _t('Vous avez une ou plusieurs demandes de matières premières qui nécessitent votre traitement. '
              'Veuillez consulter les détails et prendre une décision.'),
          style: const TextStyle(fontSize: 14, height: 1.45, color: kCrmTextSub),
        ),
        const Divider(height: 28, color: kCrmBorder),
        if (_success != null) _banner(const ValueKey('pending-success'), Icons.check_circle_rounded, kCrmSuccess, _success!),
        if (_error != null) _banner(const ValueKey('pending-error'), Icons.error_outline_rounded, kCrmDanger, _error!),
        _body(),
      ]),
    );
  }

  Widget _header() => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: kRawMaterialPendingColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.pending_actions_rounded, color: kRawMaterialPendingColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(_t(widget.oneAtATime ? 'Demande(s) de matières premières en attente' : 'Demandes à valider'),
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kCrmText)),
            if (!_loading && _loadError == null)
              Container(
                key: const ValueKey('pending-count'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: kRawMaterialPendingColor, borderRadius: BorderRadius.circular(20)),
                child: Text('$_total ${_t('en attente')}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
          ]),
        ),
        if (widget.onClose != null)
          IconButton(
            tooltip: _t('Fermer'),
            onPressed: _busy ? null : widget.onClose,
            icon: const Icon(Icons.close_rounded, color: kCrmTextSub),
          )
        else
          IconButton(
            key: const ValueKey('pending-refresh'),
            tooltip: _t('Actualiser'),
            onPressed: _busy || _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
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
        Text('${_t('Chargement impossible')} : $_loadError', key: const ValueKey('pending-load-error'), style: const TextStyle(color: kCrmDanger)),
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
          Text(_t(_success == null ? 'Aucune demande à valider pour le moment.' : 'Toutes les demandes en attente ont été traitées.'),
              key: const ValueKey('pending-empty'), style: const TextStyle(fontWeight: FontWeight.w700, color: kCrmText)),
          if (widget.onClose != null) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: widget.onClose, child: Text(_t('Fermer'))),
          ],
        ]),
      );
    }
    if (!widget.oneAtATime) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final r in _items) ...[_request(r, suffix: '-${r.requestNumber}'), const SizedBox(height: 22)],
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_items.length > 1)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            key: const ValueKey('pending-prev'),
            tooltip: _t('Demande précédente'),
            onPressed: _busy || _index == 0 ? null : () => setState(() => _index--),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text('${_t('Demande')} ${_index + 1} / ${_items.length}',
              key: const ValueKey('pending-position'), style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            key: const ValueKey('pending-next'),
            tooltip: _t('Demande suivante'),
            onPressed: _busy || _index >= _items.length - 1 ? null : () => setState(() => _index++),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ]),
      _request(_items[_index]),
    ]);
  }

  // Une demande : informations, matières, actions. [suffix] distingue les
  // boutons de chaque demande sur la page (toutes affichées).
  Widget _request(RawMaterialRequestRecord r, {String suffix = ''}) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _info(r),
        const SizedBox(height: 14),
        RawMaterialItemsTable(items: r.items),
        const SizedBox(height: 14),
        Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 8, children: [
          OutlinedButton.icon(
            key: ValueKey('pending-details$suffix'),
            onPressed: _busy ? null : () => _details(r),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(_t('Consulter les détails')),
          ),
          FilledButton.icon(
            key: ValueKey('pending-reject$suffix'),
            style: FilledButton.styleFrom(backgroundColor: kCrmDanger),
            onPressed: _busy ? null : () => _reject(r),
            icon: const Icon(Icons.close_rounded),
            label: Text(_t('Rejeter la demande')),
          ),
          FilledButton.icon(
            key: ValueKey('pending-validate$suffix'),
            style: FilledButton.styleFrom(backgroundColor: kCrmSuccess),
            onPressed: _busy ? null : () => _validate(r),
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded),
            label: Text(_t('Valider cette demande')),
          ),
        ]),
      ]);

  Widget _info(RawMaterialRequestRecord r) {
    final entries = [
      ('N° demande', r.requestNumber),
      ('Date et heure de soumission', _dateTime(r.createdAt)),
      ('Demandeur', r.userEmail),
      ('Date de production', _day(r.productionDate)),
      ('Poste', _t(rawMaterialPosteLabel(r.poste))),
      ('Validation requise avant', r.deadlineAt == null ? '—' : _dateTime(r.deadlineAt)),
    ];
    return Container(
      key: ValueKey('pending-card-${r.requestNumber}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kCrmBorder)),
      child: Wrap(spacing: 28, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
        for (final (label, value) in entries)
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(_t(label), style: const TextStyle(fontSize: 11.5, color: kCrmTextSub, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 14, color: kCrmText, fontWeight: FontWeight.w700)),
          ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(_t('Statut'), style: const TextStyle(fontSize: 11.5, color: kCrmTextSub, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          RawMaterialStatusChip(r.status),
        ]),
        if (r.overdue) RawMaterialDeadlineChip(overdue: true, key: ValueKey('pending-overdue-${r.requestNumber}')),
        if (r.dueSoon) RawMaterialDeadlineChip(overdue: false, key: ValueKey('pending-due-soon-${r.requestNumber}')),
      ]),
    );
  }
}

/// Rejet : motif obligatoire (aussi exigé par le backend).
class _RejectDialog extends StatefulWidget {
  final String requestNumber;
  const _RejectDialog({required this.requestNumber});

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
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
      title: Text('${t('Rejeter la demande')} ${widget.requestNumber}'),
      content: SizedBox(
        width: 460,
        child: TextField(
          key: const ValueKey('reject-comment'),
          controller: _comment,
          autofocus: true,
          maxLength: 1000,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: t('Motif du rejet (obligatoire)'),
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t('Annuler'))),
        FilledButton(
          key: const ValueKey('confirm-reject'),
          style: FilledButton.styleFrom(backgroundColor: kCrmDanger),
          onPressed: () {
            final text = _comment.text.trim();
            if (text.isEmpty) {
              setState(() => _error = t('Le motif du rejet est obligatoire.'));
              return;
            }
            Navigator.of(context).pop(text);
          },
          child: Text(t('Rejeter')),
        ),
      ],
    );
  }
}
