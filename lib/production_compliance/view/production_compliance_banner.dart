// lib/production_compliance/view/production_compliance_banner.dart
//
// Bandeau des comptes PROD 1 / PROD 2 (tableaux de bord PROMESH / PROBAR et
// page Output) : fiche précédente manquante + état de la demande
// d'autorisation + bouton « Demander l'autorisation », ou rattrapage autorisé
// (bouton de création de la fiche de la date autorisée). Invisible pour tous
// les autres utilisateurs. Il n'empêche JAMAIS d'ouvrir la page : le blocage
// réel est appliqué par le backend uniquement à la création / à la
// modification de date d'une fiche.
//
// Affichage compact : nombre de dates manquantes et d'autorisations en tête,
// détail (toutes les dates, toutes les autorisations) dans des zones
// repliables. Les autorisations accordées ensemble (même responsable, même
// date d'accord, même expiration) sont regroupées, leurs dates triées.
// Aucune information n'est retirée : tout reste consultable en dépliant.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../service/production_compliance_service.dart';
import 'production_compliance_dialogs.dart';

/// Au-delà, les dates / autorisations sont repliées par défaut.
const int kComplianceBannerExpandedMax = 3;

/// Hauteur maximale de la zone des dates manquantes dépliée (défilement au-delà).
const double kComplianceBannerDatesMaxHeight = 120;

class ProductionComplianceBanner extends StatefulWidget {
  /// Appelé avec la date (YYYY-MM-DD) dont la fiche de rattrapage doit être créée
  /// (null = le bouton de création n'est pas proposé, ex. page Output).
  final Future<void> Function(String date)? onBackfill;

  /// Situation chargée (GET /production-compliance/me) — permet à la page de
  /// réutiliser les dates manquantes (alertes) sans second appel.
  final ValueChanged<Map<String, dynamic>>? onLoaded;

  const ProductionComplianceBanner({super.key, this.onBackfill, this.onLoaded});

  /// Tests uniquement : remplace GET /production-compliance/me.
  @visibleForTesting
  static Future<Map<String, dynamic>> Function()? debugLoadStatus;

  @override
  State<ProductionComplianceBanner> createState() => _ProductionComplianceBannerState();
}

/// Autorisations de rattrapage accordées ensemble.
class _AuthGroup {
  final String? by;
  final DateTime? at;
  final DateTime? exp;
  final List<String> dates = [];
  _AuthGroup(this.by, this.at, this.exp);
}

class _ProductionComplianceBannerState extends State<ProductionComplianceBanner> {
  late Future<Map<String, dynamic>> _future;
  bool? _datesOpen;
  bool? _authsOpen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = (ProductionComplianceBanner.debugLoadStatus ?? ProductionComplianceService.instance.me)().catchError((_) => <String, dynamic>{}).then((me) {
      widget.onLoaded?.call(me);
      return me;
    });
  }

  String _t(String k) => AppLocalizations.of(context).translate(k);

  String _fmt(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd/MM/yyyy').format(d);
  }

  String _fmtDateTime(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());

  /// La demande la plus récente qui couvre au moins une des dates encore manquantes.
  Map<String, dynamic>? _latestCovering(List<Map<String, dynamic>> reqs, List<String> missing) {
    for (final r in reqs) {
      final covered = ((r['missingDates'] as List?) ?? [r['missingDate']]).map((e) => e?.toString());
      if (covered.any(missing.contains)) return r;
    }
    return null;
  }

  List<_AuthGroup> _group(List<Map<String, dynamic>> auths) {
    final groups = <String, _AuthGroup>{};
    for (final a in auths) {
      final by = a['authorizedByEmail']?.toString();
      final at = DateTime.tryParse(a['authorizedAt']?.toString() ?? '');
      final exp = DateTime.tryParse(a['expiresAt']?.toString() ?? '');
      final key = '$by|${a['authorizedAt']}|${a['expiresAt']}';
      groups.putIfAbsent(key, () => _AuthGroup(by, at, exp)).dates.add(a['date'].toString());
    }
    final list = groups.values.toList();
    for (final g in list) {
      g.dates.sort();
    }
    // Expiration la plus proche d'abord (les autorisations à utiliser en priorité).
    list.sort((a, b) => (a.exp ?? DateTime(9999)).compareTo(b.exp ?? DateTime(9999)));
    return list;
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
        final backfillAuths = (me['backfillDates'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        final reqs = (me['requests'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        if (missing.isEmpty && backfillAuths.isEmpty) return const SizedBox.shrink();

        final color = backfillAuths.isNotEmpty && missing.isEmpty ? Colors.green : Colors.orange;
        return Container(
          key: const ValueKey('compliance-banner'),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (missing.isNotEmpty) _missingSection(me, missing, reqs),
            if (missing.isNotEmpty && backfillAuths.isNotEmpty) const Divider(height: 20),
            if (backfillAuths.isNotEmpty) _authsSection(backfillAuths, fr),
          ]),
        );
      },
    );
  }

  // ── Dates manquantes ──────────────────────────────────────────────────
  Widget _missingSection(Map<String, dynamic> me, List<String> missing, List<Map<String, dynamic>> reqs) {
    final req = _latestCovering(reqs, missing);
    final status = req?['status']?.toString();
    final canRequest = status == null || status == 'REJECTED' || status == 'EXPIRED';
    final open = _datesOpen ?? missing.length <= kComplianceBannerExpandedMax;
    final sorted = [...missing]..sort();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                missing.length > 1
                    ? '${missing.length} ${_t('previous sheets are missing')}'
                    : '${_t('A previous sheet is missing')} : ${_fmt(missing.first)}',
                key: const ValueKey('compliance-missing-count'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          if (status != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: requestStatusColor(status).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(requestStatusLabel(context, status),
                  style: TextStyle(color: requestStatusColor(status), fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          if (canRequest)
            FilledButton(
              onPressed: () async {
                final r = await showAuthorizationRequestDialog(context, missingDates: missing, production: me['production']?.toString());
                if (r != null && mounted) setState(_load);
              },
              child: Text(_t('Request authorization')),
            ),
        ],
      ),
      if (missing.length > 1) ...[
        const SizedBox(height: 6),
        _toggle(
          key: const ValueKey('compliance-dates-toggle'),
          open: open,
          label: '${_t(open ? 'Masquer les dates' : 'Voir les dates')} (${missing.length})',
          onTap: () => setState(() => _datesOpen = !open),
        ),
        // Liste longue : zone à hauteur maximale, défilante (jamais une
        // colonne qui allonge la page).
        if (open)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: kComplianceBannerDatesMaxHeight),
              child: Scrollbar(
                child: SingleChildScrollView(
                  key: const ValueKey('compliance-missing-dates-scroll'),
                  primary: false,
                  child: Wrap(
                    key: const ValueKey('compliance-missing-dates'),
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final d in sorted) _dateChip(_fmt(d), Colors.orange)],
                  ),
                ),
              ),
            ),
          ),
      ],
    ]);
  }

  // ── Autorisations de rattrapage ───────────────────────────────────────
  Widget _authsSection(List<Map<String, dynamic>> auths, bool fr) {
    final groups = _group(auths);
    final open = _authsOpen ?? auths.length <= kComplianceBannerExpandedMax;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.lock_open_rounded, color: Colors.green),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            auths.length == 1
                ? '${_t('You are authorized to create the production sheet of')} ${_fmt(auths.first['date'].toString())}.'
                : '${auths.length} ${_t('autorisations de rattrapage actives')}',
            key: const ValueKey('compliance-auth-count'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ]),
      if (auths.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _toggle(
            key: const ValueKey('compliance-auths-toggle'),
            open: open,
            label: '${_t(open ? 'Masquer les autorisations' : 'Voir les autorisations')} (${auths.length})',
            onTap: () => setState(() => _authsOpen = !open),
          ),
        ),
      if (open)
        for (final g in groups) _authGroup(g, fr),
    ]);
  }

  Widget _authGroup(_AuthGroup g, bool fr) {
    return Container(
      key: ValueKey('compliance-auth-group-${g.dates.first}'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withOpacity(0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (g.by != null || g.exp != null)
          Text(
            [
              if (g.by != null) 'Authorization granted — ${g.by}${g.at != null ? ' — ${_fmtDateTime(g.at!)}' : ''}',
              if (g.exp != null) 'expire le ${_fmtDateTime(g.exp!)}',
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
          ),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final d in g.dates)
            widget.onBackfill == null
                ? _dateChip(_fmt(d), Colors.green)
                : FilledButton(
                    key: ValueKey('compliance-backfill-$d'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
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
        ]),
      ]),
    );
  }

  Widget _toggle({required Key key, required bool open, required String label, required VoidCallback onTap}) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
          ),
        ]),
      ),
    );
  }

  Widget _dateChip(String label, MaterialColor color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color.shade800)),
      );
}
