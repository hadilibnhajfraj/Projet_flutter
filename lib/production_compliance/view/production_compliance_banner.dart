// lib/production_compliance/view/production_compliance_banner.dart
//
// Bandeau des comptes PROD 1 / PROD 2 (tableaux de bord PROMESH / PROBAR et
// page Output) : fiche précédente manquante + état de la demande
// d'autorisation + bouton « Demander l'autorisation », ou rattrapage autorisé
// (bouton de création de la fiche de la date autorisée). Invisible pour tous
// les autres utilisateurs. Il n'empêche JAMAIS d'ouvrir la page : le blocage
// réel est appliqué par le backend uniquement à la création / à la
// modification de date d'une fiche.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../service/production_compliance_service.dart';
import 'production_compliance_dialogs.dart';

class ProductionComplianceBanner extends StatefulWidget {
  /// Appelé avec la date (YYYY-MM-DD) dont la fiche de rattrapage doit être créée
  /// (null = le bouton de création n'est pas proposé, ex. page Output).
  final Future<void> Function(String date)? onBackfill;
  const ProductionComplianceBanner({super.key, this.onBackfill});

  @override
  State<ProductionComplianceBanner> createState() => _ProductionComplianceBannerState();
}

class _ProductionComplianceBannerState extends State<ProductionComplianceBanner> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ProductionComplianceService.instance.me().catchError((_) => <String, dynamic>{});
  }

  String _t(String k) => AppLocalizations.of(context).translate(k);

  String _fmt(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd/MM/yyyy').format(d);
  }

  /// La demande la plus récente qui couvre au moins une des dates encore manquantes.
  Map<String, dynamic>? _latestCovering(List<Map<String, dynamic>> reqs, List<String> missing) {
    for (final r in reqs) {
      final covered = ((r['missingDates'] as List?) ?? [r['missingDate']]).map((e) => e?.toString());
      if (covered.any(missing.contains)) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        final me = snap.data;
        if (me == null || me['monitored'] != true) return const SizedBox.shrink();
        final missing = (me['missingDates'] as List? ?? []).map((e) => e.toString()).toList();
        final backfill = (me['backfillDates'] as List? ?? []).whereType<Map>().map((e) => e['date'].toString()).toList();
        final reqs = (me['requests'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        if (missing.isEmpty && backfill.isEmpty) return const SizedBox.shrink();

        final color = backfill.isNotEmpty && missing.isEmpty ? Colors.green : Colors.orange;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (missing.isNotEmpty)
              Builder(builder: (context) {
                final req = _latestCovering(reqs, missing);
                final status = req?['status']?.toString();
                final canRequest = status == null || status == 'REJECTED' || status == 'EXPIRED';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          missing.length > 1
                              ? '${missing.length} ${_t('previous sheets are missing')} : ${missing.map(_fmt).join(', ')}'
                              : '${_t('A previous sheet is missing')} : ${_fmt(missing.first)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (status != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: requestStatusColor(status).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                              child: Text(requestStatusLabel(context, status),
                                  style: TextStyle(color: requestStatusColor(status), fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                      ]),
                    ),
                    if (canRequest)
                      FilledButton(
                        onPressed: () async {
                          final r = await showAuthorizationRequestDialog(context, missingDates: missing, production: me['production']?.toString());
                          if (r != null && mounted) setState(_load);
                        },
                        child: Text(_t('Request authorization')),
                      ),
                  ]),
                );
              }),
            for (final d in backfill) ...[
              Row(children: [
                const Icon(Icons.lock_open_rounded, color: Colors.green),
                const SizedBox(width: 10),
                Expanded(child: Text('${_t('You are authorized to create the production sheet of')} ${_fmt(d)}.')),
                if (widget.onBackfill != null) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await widget.onBackfill!(d);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ProductionComplianceService.friendlyError(e, fr: fr))),
                        );
                      }
                    },
                    child: Text('${_t('Create sheet of')} ${_fmt(d)}'),
                  ),
                ],
              ]),
            ],
          ]),
        );
      },
    );
  }
}
