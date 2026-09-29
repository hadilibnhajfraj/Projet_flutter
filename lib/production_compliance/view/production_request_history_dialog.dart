// lib/production_compliance/view/production_request_history_dialog.dart
//
// Historique complet d'UNE demande Production (autorisation / désarchivage)
// — cycle de vie, journal d'audit (qui a consulté / approuvé / refusé, avec
// ancienne et nouvelle valeur) et emails envoyés. Partagé par les écrans
// "Demandes d'autorisation", "Demandes de désarchivage" et "Statistiques".
// La consultation est elle-même tracée côté backend (VIEW_HISTORY).

import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/reports/view/report_widgets.dart';
import '../service/production_requests_service.dart';
import 'production_compliance_dialogs.dart' show requestStatusColor;

const _kActionLabels = {
  'APPROVE': 'Approbation',
  'REJECT': 'Refus',
  'VIEW_HISTORY': 'Consultation',
  'VIEW_STATISTICS': 'Consultation des statistiques',
};

/// `type` : 'authorization' | 'unarchive'.
Future<void> showProductionRequestHistory(BuildContext context, {required String type, required String id}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Historique de la demande'),
      content: SizedBox(
        width: 620,
        child: FutureBuilder<Map<String, dynamic>>(
          future: ProductionRequestsService.instance.fetchRequestHistory(type, id),
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError) return Text('Erreur : ${snap.error}', style: const TextStyle(color: kRpRed));
            final data = snap.data ?? {};
            final req = Map<String, dynamic>.from(data['request'] as Map? ?? {});
            List<Map<String, dynamic>> l(String k) =>
                (data[k] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
            final timeline = l('timeline');
            final audit = l('audit');
            final emails = l('emails');
            final dates = (req['concernedDates'] as List? ?? []).map((d) => fmtDate(d)).join(', ');
            TextStyle h(BuildContext c) => const TextStyle(fontWeight: FontWeight.w800, fontSize: 13);

            return SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, runSpacing: 6, children: [
                  RpBadge(req['typeLabel']?.toString() ?? ''),
                  RpBadge(req['status']?.toString() ?? '', color: requestStatusColor(req['status']?.toString() ?? '')),
                  if (req['productionLabel'] != null) RpBadge(req['productionLabel'].toString(), color: kRpGrey),
                ]),
                const SizedBox(height: 10),
                Text('Utilisateur : ${req['userEmail'] ?? '—'}'),
                Text('Date de la demande : ${req['date'] ?? ''} ${req['time'] ?? ''}'),
                if (dates.isNotEmpty) Text('Date(s) concernée(s) : $dates'),
                if ((req['reason'] ?? '').toString().isNotEmpty) Text('Motif : ${req['reason']}'),
                if (req['expiresAt'] != null) Text('Expiration : ${fmtDateTime(req['expiresAt'])}'),
                if (req['reviewerEmail'] != null) Text('Responsable : ${req['reviewerEmail']} — ${req['reviewedDate'] ?? ''}'),
                if ((req['reviewNote'] ?? '').toString().isNotEmpty) Text('Note du responsable : ${req['reviewNote']}'),
                const Divider(height: 24),
                Text('Cycle de vie', style: h(ctx)),
                const SizedBox(height: 6),
                for (final e in timeline)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${e['date']} ${e['time']} — ${e['label']}'
                      '${e['actorEmail'] != null ? ' — ${e['actorEmail']}' : ''}'
                      '${e['oldValue'] != null || e['newValue'] != null ? ' (${e['oldValue'] ?? '∅'} → ${e['newValue'] ?? '∅'})' : ''}'
                      '${(e['note'] ?? '').toString().isNotEmpty ? ' — ${e['note']}' : ''}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                const Divider(height: 24),
                Text('Journal d\'audit', style: h(ctx)),
                const SizedBox(height: 6),
                if (audit.isEmpty) const RpEmpty('Aucune action enregistrée'),
                for (final a in audit)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${a['date']} ${a['time']} — ${_kActionLabels[a['action']] ?? a['action']} — ${a['userEmail'] ?? '—'}'
                      '${a['oldValue'] != null || a['newValue'] != null ? ' (${a['oldValue'] ?? '∅'} → ${a['newValue'] ?? '∅'})' : ''}'
                      '${a['outcome'] != 'SUCCESS' ? ' [${a['outcome']} ${a['httpStatus'] ?? ''}]' : ''}',
                      style: TextStyle(fontSize: 12.5, color: a['outcome'] == 'SUCCESS' ? null : kRpRed),
                    ),
                  ),
                const Divider(height: 24),
                Text('Emails', style: h(ctx)),
                const SizedBox(height: 6),
                if (emails.isEmpty) const RpEmpty('Aucun email du workflow Production'),
                for (final m in emails)
                  Text(
                    '${m['to']} — ${m['status']}${m['sentAt'] != null ? ' — ${fmtDateTime(m['sentAt'])}' : ''}'
                    '${m['error'] != null ? ' — ${m['error']}' : ''}',
                    style: TextStyle(fontSize: 12.5, color: m['status'] == 'SENT' ? null : kRpRed),
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
