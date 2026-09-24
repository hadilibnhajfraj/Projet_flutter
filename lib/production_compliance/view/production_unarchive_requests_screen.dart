// lib/production_compliance/view/production_unarchive_requests_screen.dart
//
// "Production — Unarchive Requests" (Administration) — écran Super Admin des
// demandes de désarchivage des fiches PROMESH/PROBAR archivées automatiquement
// (brouillon > 2h sans finalisation). Réservé aux mêmes comptes que
// Production Compliance (backend : requireManager, réutilise
// isComplianceManagerUser/cfg.managers) — jamais production_1/production_2.

import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/providers/production_unarchive_request_provider.dart';
import 'package:dash_master_toolkit/reports/view/report_widgets.dart';

import '../service/production_draft_archive_service.dart';

Color _statusColor(String status) {
  switch (status) {
    case 'APPROVED':
      return Colors.green;
    case 'REJECTED':
      return Colors.red;
    default:
      return Colors.orange;
  }
}

class ProductionUnarchiveRequestsScreen extends StatefulWidget {
  const ProductionUnarchiveRequestsScreen({super.key});

  @override
  State<ProductionUnarchiveRequestsScreen> createState() => _ProductionUnarchiveRequestsScreenState();
}

class _ProductionUnarchiveRequestsScreenState extends State<ProductionUnarchiveRequestsScreen> {
  final _provider = ProductionUnarchiveRequestProvider.to;
  final _hScroll = ScrollController();
  // §12 — section distincte "Archived production sheets" : liste DIRECTE des
  // fiches actuellement archivées, indépendante des demandes de désarchivage
  // (une fiche archivée peut très bien n'avoir aucune demande en cours — ça
  // ne veut pas dire qu'elle n'est pas archivée, source de confusion signalée).
  final _archivedHScroll = ScrollController();
  List<Map<String, dynamic>> _archivedSheets = [];
  bool _loadingArchived = true;
  String? _archivedError;

  String _t(String k) => AppLocalizations.of(context).translate(k);
  bool get _fr => Localizations.localeOf(context).languageCode == 'fr';

  @override
  void initState() {
    super.initState();
    _loadArchivedSheets();
  }

  Future<void> _loadArchivedSheets() async {
    setState(() { _loadingArchived = true; _archivedError = null; });
    try {
      final rows = await ProductionDraftArchiveService.instance.listArchivedSheets();
      if (mounted) setState(() { _archivedSheets = rows; _loadingArchived = false; });
    } catch (e) {
      if (mounted) setState(() { _archivedError = ProductionDraftArchiveService.friendlyError(e, fr: _fr); _loadingArchived = false; });
    }
  }

  @override
  void dispose() {
    _hScroll.dispose();
    _archivedHScroll.dispose();
    super.dispose();
  }

  String _fmtDate(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '');
    return d == null ? (v?.toString() ?? '—') : DateFormat('dd/MM/yyyy').format(d.toLocal());
  }

  String _fmtDateTime(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '');
    return d == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
  }

  String _shortUser(dynamic email) {
    final s = email?.toString() ?? '';
    final i = s.indexOf('@');
    return i > 0 ? s.substring(0, i) : s;
  }

  Future<void> _view(Map<String, dynamic> r) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${_t('Request')} #${r['id'].toString().substring(0, 8)}'),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_t('User')} : ${r['userEmail']}'),
            const SizedBox(height: 4),
            Text('${_t('Fiche')} : ${r['ficheType']} #${r['ficheId'].toString().substring(0, 8)}'),
            const SizedBox(height: 4),
            Text('${_t('Production date')} : ${_fmtDate(r['dateProduction'])}'),
            const SizedBox(height: 4),
            Text('${_t('Machine')} : ${r['machine'] ?? '—'}   ${_t('Shift')} : ${r['poste'] ?? '—'}'),
            const SizedBox(height: 4),
            Text('${_t('Archived on')} : ${_fmtDateTime(r['archivedAt'])}'),
            const SizedBox(height: 4),
            Text('${_t('Reason')} : ${r['reason']}'),
            if (r['reviewerEmail'] != null) ...[
              const SizedBox(height: 4),
              Text('${_t('Manager')} : ${r['reviewerEmail']}  ${_fmtDateTime(r['reviewedAt'])}'),
              if ((r['reviewNote'] ?? '').toString().isNotEmpty) Text('${_t('Note')} : ${r['reviewNote']}'),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: _statusColor(r['status'].toString()).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(r['status'].toString(), style: TextStyle(color: _statusColor(r['status'].toString()), fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        actions: [FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(_t('Close')))],
      ),
    );
  }

  Future<void> _decide(Map<String, dynamic> r, {required bool approve}) async {
    final noteCtrl = TextEditingController();
    bool busy = false;
    String? err;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        return AlertDialog(
          title: Text(approve ? _t('Approve unarchive') : _t('Reject')),
          content: SizedBox(
            width: 440,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r['ficheType']} · ${r['userEmail']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${_t('Production date')} : ${_fmtDate(r['dateProduction'])}'),
              const SizedBox(height: 4),
              Text('${_t('Reason')} : ${r['reason']}'),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(labelText: approve ? _t('Note (optional)') : '${_t('Reason')} *', border: const OutlineInputBorder()),
              ),
              if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: const TextStyle(color: Colors.red))),
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
                      setD(() { busy = true; err = null; });
                      try {
                        if (approve) {
                          await _provider.approveRequest(r['id'].toString(), note: noteCtrl.text);
                        } else {
                          await _provider.rejectRequest(r['id'].toString(), note: noteCtrl.text.trim());
                        }
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? _t('Unarchive approved') : _t('Request rejected'))));
                        }
                      } catch (e) {
                        setD(() {
                          busy = false;
                          err = ProductionDraftArchiveService.friendlyError(e, fr: _fr);
                        });
                      }
                    },
              child: Text(approve ? _t('APPROVE') : _t('REJECT')),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t('Production — Unarchive Requests'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(_t('Requests to unarchive PROMESH/PROBAR sheets automatically archived after 2 hours in draft'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          _buildArchivedSheetsSection(),
          const SizedBox(height: 20),
          Obx(() {
            final requests = _provider.requests;
            final stats = _provider.stats;
            return ReportSection(
              title: _t('Unarchive requests'),
              icon: Icons.unarchive_rounded,
              subtitle: '${stats['PENDING'] ?? 0} ${_t('pending')}',
              children: [
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _statChip(_t('Pending'), stats['PENDING'] ?? 0, kRpAmber),
                  _statChip(_t('Approved'), stats['APPROVED'] ?? 0, kRpGreen),
                  _statChip(_t('Rejected'), stats['REJECTED'] ?? 0, kRpRed),
                ]),
                const SizedBox(height: 14),
                if (requests.isEmpty)
                  RpEmpty(_t('No request'))
                else
                  Scrollbar(
                    controller: _hScroll,
                    thumbVisibility: true,
                    notificationPredicate: (n) => n.depth == 0,
                    child: SingleChildScrollView(
                      controller: _hScroll,
                      scrollDirection: Axis.horizontal,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
                          ...ScrollConfiguration.of(context).dragDevices,
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.trackpad,
                          PointerDeviceKind.touch,
                        }),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 1200),
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
                              DataColumn(label: Text(_t('Fiche'))),
                              DataColumn(label: Text(_t('Production date'))),
                              DataColumn(label: Text(_t('Machine'))),
                              DataColumn(label: Text(_t('Shift'))),
                              DataColumn(label: Text(_t('Archived on'))),
                              DataColumn(label: Text(_t('Reason'))),
                              DataColumn(label: Text(_t('Status'))),
                              DataColumn(label: Text(_t('Actions'))),
                            ],
                            rows: [
                              for (var i = 0; i < requests.length; i++)
                                DataRow(cells: [
                                  DataCell(Text('${i + 1}')),
                                  DataCell(Text(_fmtDate(requests[i]['requestedAt']))),
                                  DataCell(Text(_shortUser(requests[i]['userEmail']))),
                                  DataCell(Text(requests[i]['userEmail']?.toString() ?? '')),
                                  DataCell(Text(requests[i]['ficheType']?.toString() ?? '')),
                                  DataCell(Text(_fmtDate(requests[i]['dateProduction']))),
                                  DataCell(Text(requests[i]['machine']?.toString() ?? '—')),
                                  DataCell(Text(requests[i]['poste']?.toString() ?? '—')),
                                  DataCell(Text(_fmtDate(requests[i]['archivedAt']))),
                                  DataCell(ConstrainedBox(
                                    constraints: const BoxConstraints(minWidth: 140, maxWidth: 200),
                                    child: Text((requests[i]['reason'] ?? '—').toString(), overflow: TextOverflow.ellipsis),
                                  )),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: _statusColor(requests[i]['status'].toString()).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                                    child: Text(requests[i]['status'].toString(), style: TextStyle(color: _statusColor(requests[i]['status'].toString()), fontWeight: FontWeight.w700)),
                                  )),
                                  DataCell(ConstrainedBox(
                                    constraints: const BoxConstraints(minWidth: 200),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      TextButton(onPressed: () => _view(requests[i]), child: Text(_t('View'))),
                                      if (requests[i]['status'] == 'PENDING') ...[
                                        const SizedBox(width: 4),
                                        OutlinedButton(onPressed: () => _decide(requests[i], approve: false), child: Text(_t('REJECT'))),
                                        const SizedBox(width: 4),
                                        FilledButton(onPressed: () => _decide(requests[i], approve: true), child: Text(_t('APPROVE'))),
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
          }),
        ]),
      ),
    );
  }

  // §12 — "Archived production sheets" : distinct des demandes de
  // désarchivage. Confirme visuellement qu'une fiche EST réellement archivée
  // même si "Unarchive requests" affiche 0/0/0 (personne n'a encore demandé
  // son désarchivage — ce n'est pas la même information).
  Widget _buildArchivedSheetsSection() {
    return ReportSection(
      title: _t('Archived production sheets'),
      icon: Icons.archive_rounded,
      subtitle: '${_archivedSheets.length}',
      children: [
        Row(children: [
          Expanded(child: Text(_t('Sheets automatically archived by the system (2h in draft) — visible here even if no unarchive request was filed yet'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12))),
          IconButton(onPressed: _loadingArchived ? null : _loadArchivedSheets, icon: const Icon(Icons.refresh_rounded), tooltip: _t('Refresh')),
        ]),
        const SizedBox(height: 8),
        if (_loadingArchived)
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()))
        else if (_archivedError != null)
          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_archivedError!, style: const TextStyle(color: Colors.red)))
        else if (_archivedSheets.isEmpty)
          RpEmpty(_t('No archived sheet'))
        else
          Scrollbar(
            controller: _archivedHScroll,
            thumbVisibility: true,
            notificationPredicate: (n) => n.depth == 0,
            child: SingleChildScrollView(
              controller: _archivedHScroll,
              scrollDirection: Axis.horizontal,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
                  ...ScrollConfiguration.of(context).dragDevices,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.touch,
                }),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 1100),
                  child: DataTable(
                    columnSpacing: 18,
                    headingRowHeight: 40,
                    dataRowMinHeight: 46,
                    dataRowMaxHeight: 56,
                    headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    dataTextStyle: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                    columns: [
                      DataColumn(label: Text(_t('Fiche'))),
                      DataColumn(label: Text(_t('Production date'))),
                      DataColumn(label: Text(_t('Machine'))),
                      DataColumn(label: Text(_t('Shift'))),
                      DataColumn(label: Text(_t('User'))),
                      DataColumn(label: Text(_t('Created'))),
                      DataColumn(label: Text(_t('Archived'))),
                      DataColumn(label: Text(_t('Archived by'))),
                      DataColumn(label: Text(_t('Reason'))),
                    ],
                    rows: [
                      for (final s in _archivedSheets)
                        DataRow(cells: [
                          DataCell(Text(s['ficheType'] == 'PROMESH' ? (s['numero']?.toString() ?? '—') : '${s['ficheType']} #${s['id'].toString().substring(0, 8)}')),
                          DataCell(Text(_fmtDate(s['dateProduction']))),
                          DataCell(Text(s['machine']?.toString() ?? '—')),
                          DataCell(Text(s['poste']?.toString() ?? '—')),
                          DataCell(Text(_shortUser(s['userEmail']))),
                          DataCell(Text(_fmtDateTime(s['createdAt']))),
                          DataCell(Text(_fmtDateTime(s['archivedAt']))),
                          DataCell(Text(s['archivedBy']?.toString() ?? '—')),
                          DataCell(ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
                            child: Text((s['archiveReason'] ?? '—').toString(), overflow: TextOverflow.ellipsis),
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
  }

  Widget _statChip(String label, int value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          const SizedBox(height: 2),
          Text('$value', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
        ]),
      );
}
