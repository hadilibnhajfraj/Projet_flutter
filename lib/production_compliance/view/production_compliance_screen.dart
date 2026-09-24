// lib/production_compliance/view/production_compliance_screen.dart
//
// "Production Compliance" — vue responsable : pour PROD 1 / PROD 2, chaque
// jour travaillé avec son statut (complète, manquante, autorisation requise,
// rattrapée, passage autorisé), l'alerte e-mail, l'autorisation et le
// responsable. Les données et les règles viennent du backend (réservé aux
// responsables configurés) ; rien n'est calculé ici.

import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/providers/production_compliance_request_provider.dart';
import 'package:dash_master_toolkit/reports/view/report_widgets.dart';

import '../service/production_compliance_service.dart';
import 'production_compliance_dialogs.dart';

const _kStatuses = <String>[
  'completed',
  'missing',
  'awaiting_authorization',
  'backfill_authorized',
  'backfilled',
  'authorized_bypass',
  'pending',
];

class ProductionComplianceScreen extends StatefulWidget {
  const ProductionComplianceScreen({super.key});

  @override
  State<ProductionComplianceScreen> createState() => _ProductionComplianceScreenState();
}

class _ProductionComplianceScreenState extends State<ProductionComplianceScreen> {
  final _svc = ProductionComplianceService.instance;
  // Source unique des demandes (liste + compteurs) — la MÊME instance que le
  // badge du sidebar (Administration > Demandes > Production — Demandes
  // d'autorisation) : Approve/Reject ici met aussi à jour le badge, sans
  // double appel réseau ni état dupliqué.
  final _reqProvider = ProductionComplianceRequestProvider.to;

  DateTime _from = DateTime.now().subtract(const Duration(days: 29));
  DateTime _to = DateTime.now();
  String? _production;
  String? _userEmail;
  String? _status;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _summary = {};

  // Contrôleurs de scroll horizontal DÉDIÉS pour les 2 tableaux (Authorization
  // requests + Daily control) — CAUSE du scrollbar non fonctionnel : sans
  // contrôleur explicite, Scrollbar() récupère par défaut le
  // PrimaryScrollController le plus proche, qui est ici celui du
  // SingleChildScrollView VERTICAL de toute la page (body). Les deux
  // scrollbars horizontales se retrouvaient donc attachées au scroll
  // VERTICAL de la page au lieu du scroll HORIZONTAL de leur propre tableau :
  // la barre s'affichait mais la faire glisser ne déplaçait pas le contenu
  // (elle pilotait un autre Scrollable). Un ScrollController explicite, passé
  // à la fois au Scrollbar et au SingleChildScrollView qu'il contrôle,
  // supprime toute ambiguïté.
  final _requestsHScroll = ScrollController();
  final _dailyHScroll = ScrollController();

  String _t(String k) => AppLocalizations.of(context).translate(k);
  bool get _fr => Localizations.localeOf(context).languageCode == 'fr';
  final _df = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _requestsHScroll.dispose();
    _dailyHScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _svc.list(
        from: _df.format(_from),
        to: _df.format(_to),
        production: _production,
        status: _status,
      );
      final summary = await _svc.summary(date: _df.format(_to));
      await _reqProvider.load();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _summary = summary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ProductionComplianceService.friendlyError(e, fr: _fr);
        _loading = false;
      });
    }
  }

  String _fmtDate(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '');
    return d == null ? '' : DateFormat('dd/MM/yyyy').format(d.toLocal());
  }

  String _fmtDateTime(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '');
    return d == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
  }

  // ── Statuts ───────────────────────────────────────────────────────────────

  (String, IconData, Color) _statusInfo(String s) {
    switch (s) {
      case 'completed':
        return (_t('Completed'), Icons.check_circle_rounded, kRpGreen);
      case 'missing':
        return (_t('Missing sheet'), Icons.warning_amber_rounded, kRpAmber);
      case 'awaiting_authorization':
        return (_t('Authorization required'), Icons.lock_outline_rounded, kRpRed);
      case 'backfill_authorized':
        return (_t('Backfill authorized'), Icons.lock_open_rounded, kRpAccent);
      case 'backfilled':
        return (_t('Backfilled'), Icons.check_circle_outline_rounded, kRpGreen);
      case 'authorized_bypass':
        return (_t('Authorized bypass'), Icons.warning_amber_rounded, kRpAmber);
      default:
        return (_t('Pending'), Icons.hourglass_empty_rounded, kRpGrey);
    }
  }

  Widget _statusBadge(String s) {
    final (label, icon, color) = _statusInfo(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  String _authLabel(Map<String, dynamic>? a) {
    if (a == null) return '—';
    final type = a['type'] == 'BYPASS_MISSING_PRODUCTION_DATE' ? _t('Bypass') : _t('Backfill');
    final parts = <String>[type];
    if (a['usedAt'] != null) parts.add(_t('used'));
    if (a['revokedAt'] != null) parts.add(_t('revoked'));
    if (a['expiresAt'] != null && a['usedAt'] == null && a['revokedAt'] == null) {
      parts.add('${_t('expires')} ${_fmtDateTime(a['expiresAt'])}');
    }
    return parts.join(' · ');
  }

  String _alertLabel(Map<String, dynamic>? a) {
    if (a == null) return '—';
    switch (a['status']) {
      case 'sent':
        return '${_t('Email sent')} ${_fmtDateTime(a['emailSentAt'])}';
      case 'failed':
        // §13 du ticket SMTP : message explicite quand le fournisseur SMTP
        // a lui-même refusé l'envoi (554 5.7.1 côté Hostinger, par ex.).
        return '${_t('Email failed')} — ${_t('SMTP rejected outbound email.')}';
      default:
        return _t('Pending');
    }
  }

  // ── Autorisation ──────────────────────────────────────────────────────────

  Future<void> _authorize(Map<String, dynamic> row) async {
    final reasonCtrl = TextEditingController(text: '${_t('Backfill of the sheet not created on')} ${_fmtDate(row['date'])}');
    String type = 'BACKFILL_PREVIOUS_PRODUCTION';
    bool saving = false;
    String? err;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        return AlertDialog(
          title: Text(_t('Authorize backfill')),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_t('Date concerned')} : ${_fmtDate(row['date'])}'),
              const SizedBox(height: 4),
              Text('${_t('User')} : ${row['userEmail']}'),
              const SizedBox(height: 4),
              Text('${_t('Production')} : ${row['production']}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                isExpanded: true,
                decoration: InputDecoration(labelText: _t('Authorization type'), border: const OutlineInputBorder(), isDense: true),
                items: [
                  DropdownMenuItem(value: 'BACKFILL_PREVIOUS_PRODUCTION', child: Text(_t('Create the sheet of this previous date'))),
                  DropdownMenuItem(value: 'BYPASS_MISSING_PRODUCTION_DATE', child: Text(_t('Allow today\'s sheet despite this missing date'))),
                ],
                onChanged: (v) => setD(() => type = v ?? type),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(labelText: _t('Reason'), border: const OutlineInputBorder()),
              ),
              if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: const TextStyle(color: kRpRed))),
            ]),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.of(ctx).pop(), child: Text(_t('Cancel'))),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setD(() {
                        saving = true;
                        err = null;
                      });
                      try {
                        await _svc.authorize(
                          production: row['productionKey'].toString(),
                          date: row['date'].toString(),
                          type: type,
                          reason: reasonCtrl.text,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('Authorization saved'))));
                          _load();
                        }
                      } catch (e) {
                        setD(() {
                          saving = false;
                          err = ProductionComplianceService.friendlyError(e, fr: _fr);
                        });
                      }
                    },
              child: Text(_t('Authorize')),
            ),
          ],
        );
      }),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t('Production Compliance'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(_t('Daily production sheet control — Tunis time'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          _filters(),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kRpRed.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: kRpRed),
                const SizedBox(width: 10),
                Expanded(child: Text(_error!)),
                TextButton(onPressed: _load, child: Text(_t('Retry'))),
              ]),
            )
          else ...[
            _requestsSection(),
            _summarySection(),
            _tableSection(),
          ],
        ]),
      ),
    );
  }

  Widget _dateBox(String label, DateTime d, ValueChanged<DateTime> onPick) => SizedBox(
        width: 150,
        child: InkWell(
          onTap: () async {
            final p = await showDatePicker(context: context, initialDate: d, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (p != null) {
              onPick(p);
              _load();
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
            child: Text(DateFormat('dd/MM/yyyy').format(d)),
          ),
        ),
      );

  Widget _filters() {
    final users = {for (final r in _rows) r['userEmail'].toString()}.toList()..sort();
    Widget dd(String label, String? value, List<(String, String)> opts, ValueChanged<String?> on, {double width = 190}) => SizedBox(
          width: width,
          child: DropdownButtonFormField<String?>(
            value: opts.any((o) => o.$1 == value) ? value : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(_t('All'))),
              for (final o in opts) DropdownMenuItem<String?>(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              setState(() => on(v));
              _load();
            },
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.6)),
      ),
      child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        _dateBox(_t('Start date'), _from, (d) => setState(() => _from = d)),
        _dateBox(_t('End date'), _to, (d) => setState(() => _to = d)),
        dd(_t('Production'), _production, const [('PROD1', 'PROD 1'), ('PROD2', 'PROD 2')], (v) => _production = v, width: 150),
        dd(_t('User'), _userEmail, [for (final u in users) (u, u)], (v) => _userEmail = v, width: 250),
        dd(_t('Status'), _status, [for (final s in _kStatuses) (s, _statusInfo(s).$1)], (v) => _status = v, width: 210),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _from = DateTime.now().subtract(const Duration(days: 29));
              _to = DateTime.now();
              _production = null;
              _userEmail = null;
              _status = null;
            });
            _load();
          },
          icon: const Icon(Icons.restart_alt_rounded),
          label: Text(_t('Reset filters')),
        ),
      ]),
    );
  }

  // ── Demandes d'autorisation de régularisation ─────────────────────────────

  Future<void> _decide(Map<String, dynamic> r, {required bool approve}) async {
    final noteCtrl = TextEditingController();
    bool busy = false;
    String? err;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        return AlertDialog(
          title: Text(approve ? _t('Authorize this request') : _t('Reject this request')),
          content: SizedBox(
            width: 440,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r['productionLabel']} · ${r['userEmail']}'),
              const SizedBox(height: 4),
              Text('${_t('Missing dates')} : ${_missingDatesOf(r).map(_fmtDate).join(', ')}', style: const TextStyle(fontWeight: FontWeight.w700)),
              if ((r['reason'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('${_t('Reason')} : ${r['reason']}'),
              ],
              if (approve) ...[
                const SizedBox(height: 8),
                Text(
                  _missingDatesOf(r).length > 1
                      ? _t('This creates one single-use backfill authorization per date, each limited to its own date.')
                      : _t('This creates a single-use backfill authorization for this date only.'),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              // Le motif est FACULTATIF pour une approbation (le motif de la demande
              // suffit déjà, affiché ci-dessus), mais OBLIGATOIRE pour un refus.
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(labelText: approve ? _t('Note (optional)') : '${_t('Reason')} *', border: const OutlineInputBorder()),
              ),
              if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: const TextStyle(color: kRpRed))),
            ]),
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.of(ctx).pop(), child: Text(_t('Cancel'))),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!approve && noteCtrl.text.trim().isEmpty) {
                        setD(() => err = _fr ? 'Le motif est obligatoire.' : 'A reason is required.');
                        return;
                      }
                      setD(() {
                        busy = true;
                        err = null;
                      });
                      try {
                        if (approve) {
                          await _reqProvider.approveRequest(r['id'].toString(), note: noteCtrl.text);
                        } else {
                          await _reqProvider.rejectRequest(r['id'].toString(), note: noteCtrl.text.trim());
                        }
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? _t('Authorization saved') : _t('Request rejected'))));
                        }
                      } catch (e) {
                        setD(() {
                          busy = false;
                          err = ProductionComplianceService.friendlyError(e, fr: _fr);
                        });
                      }
                    },
              child: Text(approve ? _t('AUTHORIZE') : _t('REJECT')),
            ),
          ],
        );
      }),
    );
  }

  List<String> _missingDatesOf(Map<String, dynamic> r) {
    final list = (r['missingDates'] as List?)?.map((e) => e.toString()).toList();
    if (list != null && list.isNotEmpty) return list;
    final single = r['missingDate']?.toString();
    return single == null ? const [] : [single];
  }

  Widget _statsChip(String label, int value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          const SizedBox(height: 2),
          Text('$value', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
        ]),
      );

  /// "Utilisateur" (nom court) dérivé de l'e-mail — ex. "production_1" pour
  /// production_1@cbi-tunisia.com — affiché à côté de la colonne "Email"
  /// (adresse complète) plutôt que de dupliquer la même valeur deux fois.
  String _shortUser(dynamic email) {
    final s = email?.toString() ?? '';
    final i = s.indexOf('@');
    return i > 0 ? s.substring(0, i) : s;
  }

  Future<void> _viewRequest(Map<String, dynamic> r) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${_t('Request')} #${r['id'].toString().substring(0, 8)}'),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_t('User')} : ${r['userEmail']}'),
            const SizedBox(height: 4),
            Text('${_t('Production')} : ${r['productionLabel'] ?? r['production']}'),
            const SizedBox(height: 4),
            Text('${_t('Requested date')} : ${_fmtDate(r['requestedDate'])}'),
            const SizedBox(height: 4),
            Text('${_t('Missing dates')} : ${_missingDatesOf(r).map(_fmtDate).join(', ')}'),
            if ((r['usedDates'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text('${_t('Regularized')} : ${(r['usedDates'] as List).map(_fmtDate).join(', ')}', style: TextStyle(color: kRpGreen)),
            ],
            if ((r['reason'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('${_t('Reason')} : ${r['reason']}'),
            ],
            const SizedBox(height: 4),
            Text('${_t('Requested on')} : ${_fmtDateTime(r['requestedAt'])}'),
            const SizedBox(height: 4),
            Text('${_t('Expires on')} : ${r['expiresAt'] != null ? _fmtDateTime(r['expiresAt']) : '—'}'),
            if (r['reviewerEmail'] != null) ...[
              const SizedBox(height: 4),
              Text('${_t('Manager')} : ${r['reviewerEmail']}  ${_fmtDateTime(r['reviewedAt'])}'),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: requestStatusColor(r['status'].toString()).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(r['status'].toString(), style: TextStyle(color: requestStatusColor(r['status'].toString()), fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        actions: [FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(_t('Close')))],
      ),
    );
  }

  Widget _requestsSection() {
    return Obx(() {
      final requests = _reqProvider.requests;
      final stats = _reqProvider.stats;
      final pending = stats['PENDING'] ?? requests.where((r) => r['status'] == 'PENDING').length;
      return ReportSection(
        title: _t('Authorization requests'),
        icon: Icons.inbox_rounded,
        subtitle: '$pending ${_t('pending')}',
        children: [
          Wrap(spacing: 10, runSpacing: 10, children: [
            _statsChip(_t('Pending'), stats['PENDING'] ?? 0, kRpAmber),
            _statsChip(_t('Approved'), stats['APPROVED'] ?? 0, kRpAccent),
            _statsChip(_t('Rejected'), stats['REJECTED'] ?? 0, kRpRed),
            _statsChip(_t('Regularized'), stats['USED'] ?? 0, kRpGreen),
            _statsChip(_t('Expired'), stats['EXPIRED'] ?? 0, kRpGrey),
          ]),
          const SizedBox(height: 14),
          if (requests.isEmpty)
            RpEmpty(_t('No request'))
          else
            // Scrollbar + SingleChildScrollView PARTAGENT le même ScrollController
            // explicite (_requestsHScroll) — sans lui, Scrollbar() attrapait par
            // défaut le PrimaryScrollController du SingleChildScrollView vertical
            // de toute la page : la barre s'affichait mais faire glisser ne
            // déplaçait pas le tableau (elle pilotait le scroll vertical de la
            // page, pas le scroll horizontal du tableau). ConstrainedBox(minWidth)
            // garantit une largeur minimale au tableau — jamais de colonne
            // écrasée — pour déclencher un vrai scroll horizontal dès que
            // l'écran est plus étroit que cette largeur.
            Scrollbar(
              controller: _requestsHScroll,
              thumbVisibility: true,
              notificationPredicate: (notif) => notif.depth == 0,
              child: SingleChildScrollView(
                controller: _requestsHScroll,
                scrollDirection: Axis.horizontal,
                // dragDevices élargi : la scrollbar reste toujours utilisable,
                // mais on permet aussi de faire glisser directement le contenu
                // à la souris (desktop/web), pas seulement au doigt.
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      ...ScrollConfiguration.of(context).dragDevices,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.touch,
                    },
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 1360),
                    child: DataTable(
                      columnSpacing: 18,
                      headingRowHeight: 40,
                      dataRowMinHeight: 46,
                      dataRowMaxHeight: 56,
                      headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      dataTextStyle: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                      columns: [
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text(_t('Request date'))),
                        DataColumn(label: Text(_t('User'))),
                        DataColumn(label: Text(_t('Email'))),
                        DataColumn(label: Text(_t('Production'))),
                        DataColumn(label: Text(_t('Requested date'))),
                        DataColumn(label: Text(_t('Missing dates'))),
                        DataColumn(label: Text(_t('Reason'))),
                        DataColumn(label: Text(_t('Status'))),
                        DataColumn(label: Text(_t('Expires on'))),
                        // §13/§10 du ticket SMTP : statut de l'e-mail distinct du statut
                        // de la demande (§12 — indépendants), avec "Retry email".
                        DataColumn(label: Text(_t('Email status'))),
                        DataColumn(label: Text(_t('Actions'))),
                      ],
                      rows: [
                        for (var i = 0; i < requests.length; i++)
                          DataRow(cells: [
                            DataCell(Text('${i + 1}')),
                            DataCell(Text(_fmtDate(requests[i]['requestedAt']))),
                            DataCell(Text(_shortUser(requests[i]['userEmail']))),
                            DataCell(Text(requests[i]['userEmail']?.toString() ?? '')),
                            DataCell(Text((requests[i]['productionLabel'] ?? requests[i]['production'] ?? '').toString())),
                            DataCell(Text(_fmtDate(requests[i]['requestedDate']))),
                            DataCell(ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 160, maxWidth: 200),
                              child: Text(_missingDatesOf(requests[i]).map(_fmtDate).join(', '), overflow: TextOverflow.ellipsis),
                            )),
                            DataCell(ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text((requests[i]['reason'] ?? '—').toString(), overflow: TextOverflow.ellipsis),
                            )),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: requestStatusColor(requests[i]['status'].toString()).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                              child: Text(requests[i]['status'].toString(), style: TextStyle(color: requestStatusColor(requests[i]['status'].toString()), fontWeight: FontWeight.w700)),
                            )),
                            DataCell(Text(requests[i]['expiresAt'] != null ? _fmtDate(requests[i]['expiresAt']) : '—')),
                            DataCell(_emailStatusChip(requests[i]['emailStatus']?.toString())),
                            DataCell(ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 260),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                TextButton(onPressed: () => _viewRequest(requests[i]), child: Text(_t('View'))),
                                if (requests[i]['status'] == 'PENDING') ...[
                                  const SizedBox(width: 4),
                                  OutlinedButton(onPressed: () => _decide(requests[i], approve: false), child: Text(_t('REJECT'))),
                                  const SizedBox(width: 4),
                                  FilledButton(onPressed: () => _decide(requests[i], approve: true), child: Text(_t('AUTHORIZE'))),
                                ],
                                if (requests[i]['emailStatus'] == 'FAILED') ...[
                                  const SizedBox(width: 4),
                                  OutlinedButton.icon(
                                    onPressed: () => _retryRequestEmail(requests[i]['id'].toString()),
                                    icon: const Icon(Icons.refresh_rounded, size: 16),
                                    label: Text(_t('Retry email')),
                                  ),
                                ],
                              ]),
                            )),
                          ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _summarySection() {
    final prods = (_summary['productions'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return ReportSection(
      title: '${_t('Compliance summary')} — ${_fmtDate(_summary['date'])}',
      icon: Icons.fact_check_rounded,
      children: [
        Wrap(spacing: 14, runSpacing: 14, children: [
          for (final p in prods) _summaryCard(p),
        ]),
      ],
    );
  }

  Widget _summaryCard(Map<String, dynamic> p) {
    final today = p['today'] is Map ? Map<String, dynamic>.from(p['today'] as Map) : null;
    List<Map<String, dynamic>> l(dynamic v) => (v as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final missing = l(p['missing']);
    final backfilled = l(p['backfilled']);
    final auths = l(p['authorizations']);
    return Container(
      width: 420,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${p['label']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(width: 10),
          Text('${p['periodStart'] ?? ''} → ${p['periodEnd'] ?? ''}', style: const TextStyle(fontSize: 12)),
        ]),
        Text('${p['email']}', style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 10),
        if (p['userFound'] == false)
          Text(_t('Not available'))
        else ...[
          Row(children: [
            Text('${_fmtDate(_summary['date'])} : '),
            if (today != null) _statusBadge(today['status'].toString()) else Text(_t('Not a working day')),
          ]),
          const SizedBox(height: 8),
          for (final m in missing)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(children: [
                Text('${_fmtDate(m['date'])} : '),
                _statusBadge(m['status'].toString()),
              ]),
            ),
          if (backfilled.isNotEmpty)
            Text('${_t('Backfilled')} : ${backfilled.map((r) => _fmtDate(r['date'])).join(', ')}', style: const TextStyle(fontSize: 12)),
          if (auths.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(_t('Authorizations'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            for (final a in auths)
              Text('${_fmtDate(a['date'])} · ${_authLabel(a)} · ${a['authorizedBy']}', style: const TextStyle(fontSize: 12)),
          ],
        ],
      ]),
    );
  }

  /// Action de la colonne "Action" (Daily Control) pour un jour donné : le bouton
  /// "Authorize backfill" UNIQUEMENT si aucune demande ne couvre déjà cette date
  /// (jamais un 2e bouton / une 2e voie d'autorisation, §13) — sinon un simple
  /// libellé "Request pending" / "Authorization granted" reflétant la demande
  /// existante (coveringRequestId/coveringRequestStatus renvoyés par le backend).
  Widget _dayAction(Map<String, dynamic> r) {
    final children = <Widget>[];
    if (r['canAuthorize'] == true) {
      children.add(FilledButton.tonal(onPressed: () => _authorize(r), child: Text(_t('Authorize backfill'))));
    } else {
      final coveringStatus = r['coveringRequestStatus']?.toString();
      if (coveringStatus != null) {
        final label = coveringStatus == 'PENDING' ? _t('Request pending') : _t('Authorization granted');
        final color = coveringStatus == 'PENDING' ? kRpAmber : kRpAccent;
        children.add(Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ));
      }
    }
    // "Retry email" (§10 du ticket SMTP) : indépendant du statut du jour
    // (§12 — un e-mail échoué n'affecte jamais la conformité elle-même).
    final alert = r['alert'] is Map ? Map<String, dynamic>.from(r['alert'] as Map) : null;
    if (alert != null && alert['status'] == 'failed' && alert['id'] != null) {
      children.add(OutlinedButton.icon(
        onPressed: () => _retryAlertEmail(alert['id'].toString()),
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: Text(_t('Retry email')),
      ));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: children);
  }

  Future<void> _retryAlertEmail(String alertId) async {
    try {
      await _svc.retryAlertEmail(alertId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('Email retried'))));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ProductionComplianceService.friendlyError(e, fr: _fr)), backgroundColor: kRpRed));
    }
  }

  /// §12 — l'e-mail est indépendant du statut de la demande elle-même (la
  /// notification CRM, elle, est toujours créée — voir requests.service.js).
  Widget _emailStatusChip(String? status) {
    switch (status) {
      case 'SENT':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: kRpGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(_t('Email sent'), style: TextStyle(color: kRpGreen, fontSize: 12, fontWeight: FontWeight.w600)),
        );
      case 'FAILED':
        return Tooltip(
          message: _t('SMTP rejected outbound email.'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: kRpRed.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(_t('Email failed'), style: TextStyle(color: kRpRed, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        );
      default:
        return Text(_t('Pending'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12));
    }
  }

  Future<void> _retryRequestEmail(String requestId) async {
    try {
      await _svc.retryRequestEmail(requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('Email retried'))));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ProductionComplianceService.friendlyError(e, fr: _fr)), backgroundColor: kRpRed));
    }
  }

  Widget _tableSection() {
    final rows = _userEmail == null ? _rows : _rows.where((r) => r['userEmail'] == _userEmail).toList();
    final cols = <RpCol>[
      RpCol(_t('Date'), (r) => _fmtDate(r['date'])),
      RpCol(_t('Production'), (r) => r['production'].toString()),
      RpCol(_t('User'), (r) => r['userEmail'].toString()),
      RpCol(_t('Period'), (r) => '${r['periodStart']} → ${r['periodEnd']}'),
      RpCol(_t('Sheets created'), (r) => '${r['sheetsCount']} (${r['sheetsInWindow']} ${_t('in period')})', numeric: true),
      RpCol(_t('Alert'), (r) => _alertLabel(r['alert'] is Map ? Map<String, dynamic>.from(r['alert'] as Map) : null)),
      RpCol(_t('Authorization'), (r) => _authLabel(r['authorization'] is Map ? Map<String, dynamic>.from(r['authorization'] as Map) : null)),
      RpCol(_t('Manager'), (r) => (r['authorization'] is Map ? (r['authorization'] as Map)['authorizedBy']?.toString() : null) ?? '—'),
    ];
    return ReportSection(
      title: _t('Daily control'),
      icon: Icons.event_available_rounded,
      subtitle: '${rows.length} ${_t('rows')}',
      children: [
        if (rows.isEmpty)
          RpEmpty(_t('Not available'))
        else
          // Même correctif que "Authorization requests" ci-dessus : ScrollController
          // dédié explicite (même bug de scrollbar non fonctionnelle ici aussi).
          Scrollbar(
            controller: _dailyHScroll,
            thumbVisibility: true,
            notificationPredicate: (notif) => notif.depth == 0,
            child: SingleChildScrollView(
              controller: _dailyHScroll,
              scrollDirection: Axis.horizontal,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    ...ScrollConfiguration.of(context).dragDevices,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.touch,
                  },
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 1360),
                  child: DataTable(
                    columnSpacing: 20,
                    headingRowHeight: 40,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 52,
                    headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    dataTextStyle: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                    columns: [
                      for (final c in cols) DataColumn(label: Text(c.header), numeric: c.numeric),
                      DataColumn(label: Text(_t('Status'))),
                      DataColumn(label: Text(_t('Action'))),
                    ],
                    rows: [
                      for (final r in rows)
                        DataRow(cells: [
                          for (final c in cols) DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 240), child: Text(c.value(r), overflow: TextOverflow.ellipsis))),
                          DataCell(_statusBadge(r['status'].toString())),
                          DataCell(ConstrainedBox(constraints: const BoxConstraints(minWidth: 180), child: _dayAction(r))),
                        ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
