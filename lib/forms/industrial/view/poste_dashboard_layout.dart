// lib/forms/industrial/view/poste_dashboard_layout.dart
//
// Système de design commun aux pages machine/poste PROMESH et PROBAR
// (PosteDashboardScreen, ProbarPosteDashboardScreen) : en-tête machine,
// barre d'actions, alertes, KPI compacts, panneaux de graphiques et tableau
// « Fiches récentes ». Composants de PRÉSENTATION uniquement : ils affichent
// ce que l'écran leur donne (données backend) et appellent ses callbacks —
// aucune règle métier, aucun appel réseau, aucune route codée ici (fichier
// sans dépendance web, testable hors navigateur).
//
// Couleurs : PROMESH bleu, PROBAR orange (couleur de ligne passée par
// l'écran) ; acceptée vert, en attente orange, refusée / anomalie rouge,
// brouillon gris. Textes traduits par AppLocalizations (assets/lang).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/production_dashboard/model/production_dashboard_model.dart' show prodFormatNumber;

const Color kPosteAccepted = Color(0xFF16A34A);
const Color kPostePending = Color(0xFFEA580C);
const Color kPosteRejected = Color(0xFFDC2626);
const Color kPosteNeutral = Color(0xFF64748B);
const Color kPosteFinished = Color(0xFF0E7490); // saisie terminée, hors circuit de validation

const double _radius = 12;

/// Traduction (clé française → langue de l'application) ; sans délégué de
/// localisation (tests), la clé est affichée telle quelle.
String pdT(BuildContext context, String key) => Localizations.of<AppLocalizations>(context, AppLocalizations)?.translate(key) ?? key;

/// Modèle à valeurs : « {0} fiches manquantes ».
String pdTf(BuildContext context, String key, List<Object> values) {
  var out = pdT(context, key);
  for (var i = 0; i < values.length; i++) {
    out = out.replaceAll('{$i}', '${values[i]}');
  }
  return out;
}

String pdPosteLabel(String? poste) => switch (poste) {
      'matin' => 'Matin',
      null || '' => '—',
      _ => 'Soir', // valeur backend 'nuit' : libellé « Soir » partout dans Production
    };

String pdQuantity(double? v, String unit) => v == null ? '—' : '${prodFormatNumber(v)} $unit';

String pdDate(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  return d == null ? (iso ?? '—') : DateFormat('dd/MM/yyyy').format(d);
}

BoxDecoration _card() => BoxDecoration(
      color: kCrmSurface,
      borderRadius: BorderRadius.circular(_radius),
      border: Border.all(color: kCrmBorder),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
    );

// ═══ En-tête machine ═════════════════════════════════════════════════════

class PosteHeader extends StatelessWidget {
  final String lineLabel; // PROMESH | PROBAR
  final Color color;
  final String machine;
  final String poste;
  final DateTime now;
  final String? operatorName;
  final VoidCallback onBack;

  const PosteHeader({super.key, required this.lineLabel, required this.color, required this.machine, required this.poste, required this.now, this.operatorName, required this.onBack});

  @override
  Widget build(BuildContext context) {
    Widget meta(IconData icon, String text, {Key? key}) => Row(key: key, mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: kCrmTextSub),
          const SizedBox(width: 5),
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmTextSub))),
        ]);
    return Container(
      key: const ValueKey('poste-header'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(10, 12, 16, 12),
      decoration: _card(),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Accent de la ligne (bleu PROMESH / orange PROBAR).
        Container(width: 4, height: 46, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Tooltip(
          message: pdT(context, 'Retour'),
          child: InkWell(
            key: const ValueKey('poste-back'),
            onTap: onBack,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(border: Border.all(color: kCrmBorder), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.arrow_back_rounded, size: 16, color: kCrmTextSub),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.precision_manufacturing_outlined, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(lineLabel, key: const ValueKey('poste-line'), style: tInter(fontSize: 11.5, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.8)),
            Text('${pdT(context, 'Machine')} $machine', key: const ValueKey('poste-machine'), style: tInter(fontSize: 22, fontWeight: FontWeight.w900, color: kCrmText, height: 1.15)),
            const SizedBox(height: 4),
            Wrap(spacing: 16, runSpacing: 4, children: [
              meta(poste == 'matin' ? Icons.wb_sunny_outlined : Icons.nightlight_outlined, '${pdT(context, 'Poste')} ${pdT(context, pdPosteLabel(poste))}', key: const ValueKey('poste-shift')),
              meta(Icons.event_outlined, DateFormat('dd/MM/yyyy').format(now)),
              meta(Icons.schedule_outlined, DateFormat('HH:mm').format(now)),
              if (operatorName != null && operatorName!.trim().isNotEmpty) meta(Icons.person_outline_rounded, operatorName!),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ═══ Barre d'actions ═════════════════════════════════════════════════════

class PosteAction {
  final String key;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool busy;
  const PosteAction(this.key, {required this.label, required this.icon, this.onTap, this.busy = false});
}

class PosteActionBar extends StatelessWidget {
  final Color color;
  final PosteAction primary;
  final List<PosteAction> secondary;

  const PosteActionBar({super.key, required this.color, required this.primary, this.secondary = const []});

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withValues(alpha: 0.9)));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        FilledButton.icon(
          key: ValueKey('poste-action-${primary.key}'),
          onPressed: primary.onTap,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            disabledBackgroundColor: color.withValues(alpha: 0.55),
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
          icon: primary.busy ? spinner : Icon(primary.icon, size: 19),
          label: Text(pdT(context, primary.label), style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        for (final a in secondary)
          OutlinedButton.icon(
            key: ValueKey('poste-action-${a.key}'),
            onPressed: a.onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: kCrmText,
              side: const BorderSide(color: kCrmBorder),
              backgroundColor: kCrmSurface,
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
            icon: a.busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(a.icon, size: 17, color: kCrmTextSub),
            label: Text(pdT(context, a.label), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText)),
          ),
      ]),
    );
  }
}

// ═══ KPI compacts ════════════════════════════════════════════════════════

class PosteKpi {
  final String key;
  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Color color;
  const PosteKpi(this.key, {required this.icon, required this.label, required this.value, this.caption, required this.color});
}

/// Grand écran : jusqu'à 6 par rangée ; tablette : 3 ; petit écran : 2 (1
/// sous 300 px).
int posteKpiColumns(double width, int count) {
  final max = width >= 1200 ? 6 : (width >= 900 ? 3 : (width >= 300 ? 2 : 1));
  return count < max ? count : max;
}

class PosteKpiGrid extends StatelessWidget {
  final List<PosteKpi> items;
  final bool loading;
  final int skeletonCount;

  const PosteKpiGrid({super.key, required this.items, this.loading = false, this.skeletonCount = 6});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(builder: (context, c) {
        final n = loading ? skeletonCount : items.length;
        final cols = posteKpiColumns(c.maxWidth, n);
        const gap = 10.0;
        final w = (c.maxWidth - (cols - 1) * gap) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (var i = 0; i < n; i++) SizedBox(width: w, child: loading ? const _KpiSkeleton() : _KpiTile(items[i])),
        ]);
      }),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final PosteKpi k;
  const _KpiTile(this.k);

  @override
  Widget build(BuildContext context) => Container(
        key: ValueKey('poste-kpi-${k.key}'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: _card(),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: k.color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(9)),
            child: Icon(k.icon, size: 18, color: k.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(pdT(context, k.label), maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w600, color: kCrmTextSub)),
              Text(k.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 19, fontWeight: FontWeight.w800, color: kCrmText, letterSpacing: -0.3)),
              if (k.caption != null) Text(k.caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 10.5, color: kCrmTextSub)),
            ]),
          ),
        ]),
      );
}

class _KpiSkeleton extends StatelessWidget {
  const _KpiSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        height: 56,
        padding: const EdgeInsets.all(12),
        decoration: _card(),
        child: Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: kCrmBorder, borderRadius: BorderRadius.circular(9))),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 14, decoration: BoxDecoration(color: kCrmBorder, borderRadius: BorderRadius.circular(4)))),
        ]),
      );
}

// ═══ Alertes et actions requises ═════════════════════════════════════════

enum PosteSeverity { critical, warning }

class PosteAlert {
  final String key;
  final PosteSeverity severity;
  final IconData icon;
  final String title;
  final int count;
  final String description;
  final String? actionLabel;
  final VoidCallback? onTap;
  const PosteAlert(this.key, {required this.severity, required this.icon, required this.title, required this.count, required this.description, this.actionLabel, this.onTap});
}

class PosteAlertsPanel extends StatelessWidget {
  final List<PosteAlert> alerts;
  final bool loading;

  const PosteAlertsPanel({super.key, required this.alerts, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final sorted = [...alerts]..sort((a, b) => a.severity.index.compareTo(b.severity.index));
    if (loading) return const SizedBox.shrink();
    if (sorted.isEmpty) {
      return Container(
        key: const ValueKey('poste-alerts-none'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: kPosteAccepted.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: kPosteAccepted.withValues(alpha: 0.25))),
        child: Row(children: [
          const Icon(Icons.check_circle_outline_rounded, size: 18, color: kPosteAccepted),
          const SizedBox(width: 10),
          Expanded(child: Text(pdT(context, 'Aucun problème nécessitant une intervention'), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText))),
        ]),
      );
    }
    return Container(
      key: const ValueKey('poste-alerts'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.notification_important_outlined, size: 18, color: kPosteRejected),
          const SizedBox(width: 8),
          Expanded(child: Text(pdT(context, 'Alertes et actions requises'), style: tInter(fontSize: 14, fontWeight: FontWeight.w800, color: kCrmText))),
        ]),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 900 ? 2 : 1;
          final w = (c.maxWidth - (cols - 1) * 10) / cols;
          return Wrap(spacing: 10, runSpacing: 8, children: [for (final a in sorted) SizedBox(width: w, child: _AlertTile(a))]);
        }),
      ]),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final PosteAlert a;
  const _AlertTile(this.a);

  @override
  Widget build(BuildContext context) {
    final color = a.severity == PosteSeverity.critical ? kPosteRejected : kPostePending;
    return Material(
      color: color.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        key: ValueKey('poste-alert-${a.key}'),
        onTap: a.onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border(left: BorderSide(color: color, width: 4))),
          child: Row(children: [
            Icon(a.icon, size: 19, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(pdT(context, a.title), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: kCrmText)),
                Text(pdT(context, a.description), maxLines: 2, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11.5, color: kCrmTextSub)),
              ]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
              child: Text('${a.count}', style: tInter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            if (a.actionLabel != null)
              TextButton(
                onPressed: a.onTap,
                style: TextButton.styleFrom(foregroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 30)),
                child: Text(pdT(context, a.actionLabel!), style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              ),
          ]),
        ),
      ),
    );
  }
}

// ═══ Graphiques ══════════════════════════════════════════════════════════

class PosteChartPanel extends StatelessWidget {
  final String panelKey;
  final String title;
  final String? subtitle; // unité, période
  final IconData icon;
  final Color color;
  final bool loading;
  /// null : aucune donnée → état vide [emptyMessage] (jamais de courbe inventée).
  final Widget? chart;
  final String emptyMessage;
  final Widget? legend;

  const PosteChartPanel({
    super.key,
    required this.panelKey,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.loading = false,
    required this.chart,
    this.emptyMessage = 'Aucune donnée sur cette période',
    this.legend,
  });

  @override
  Widget build(BuildContext context) => Container(
        key: ValueKey('poste-chart-$panelKey'),
        padding: const EdgeInsets.all(12),
        decoration: _card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(7)),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pdT(context, title), maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText)),
                if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11, color: kCrmTextSub)),
              ]),
            ),
          ]),
          if (legend != null) Padding(padding: const EdgeInsets.only(top: 6), child: legend!),
          const SizedBox(height: 10),
          SizedBox(
            height: 170,
            child: loading
                ? Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: color)))
                : chart ??
                    Center(
                      key: ValueKey('poste-chart-$panelKey-empty'),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.insert_chart_outlined_rounded, size: 28, color: kCrmTextSub.withValues(alpha: 0.5)),
                        const SizedBox(height: 6),
                        Text(pdT(context, emptyMessage), textAlign: TextAlign.center, style: tInter(fontSize: 12, color: kCrmTextSub)),
                      ]),
                    ),
          ),
        ]),
      );
}

/// Trois panneaux : en ligne sur grand écran, 2 + 1 sur tablette, empilés sur mobile.
class PosteChartsRow extends StatelessWidget {
  final List<Widget> panels;
  const PosteChartsRow({super.key, required this.panels});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 640 ? 2 : 1);
          const gap = 10.0;
          final w = (c.maxWidth - (cols - 1) * gap) / cols;
          return Wrap(spacing: gap, runSpacing: gap, children: [for (final p in panels) SizedBox(width: w, child: p)]);
        }),
      );
}

Widget posteLegendDot(BuildContext context, Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 9, height: 9, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 5),
      Text(label, style: tInter(fontSize: 11.5, color: kCrmText)),
    ]);

// ═══ Fiches récentes ═════════════════════════════════════════════════════

class PosteFicheRow {
  final String id;
  final String? numero;
  final String? date; // AAAA-MM-JJ
  final String? poste;
  final String? machine;
  final String? producer; // compte créateur
  final String? operateur; // opérateur saisi sur la fiche
  final double? quantity;
  final String unit;
  final bool isDraft;
  final String? approvalStatus; // APPROVED | PENDING | REJECTED | null (hors circuit)
  final String? rejectionComment;
  final DateTime? rejectedAt;
  final bool nonConforme;

  const PosteFicheRow({
    required this.id,
    this.numero,
    this.date,
    this.poste,
    this.machine,
    this.producer,
    this.operateur,
    this.quantity,
    required this.unit,
    required this.isDraft,
    this.approvalStatus,
    this.rejectionComment,
    this.rejectedAt,
    this.nonConforme = false,
  });
}

/// Statut unique et cohérent : brouillon (gris), en attente (orange),
/// acceptée (vert), refusée (rouge), terminée hors circuit de validation.
class PosteStatusBadge extends StatelessWidget {
  final PosteFicheRow row;
  const PosteStatusBadge(this.row, {super.key});

  static (String, Color, IconData) of(PosteFicheRow r) {
    if (r.isDraft) return ('Brouillon', kPosteNeutral, Icons.edit_note_rounded);
    return switch (r.approvalStatus) {
      'APPROVED' => ('Acceptée', kPosteAccepted, Icons.verified_outlined),
      'PENDING' => ('En attente', kPostePending, Icons.hourglass_top_rounded),
      'REJECTED' => ('Refusée', kPosteRejected, Icons.block_rounded),
      _ => ('Terminée', kPosteFinished, Icons.task_alt_rounded),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = of(row);
    Widget pill(String text, Color c, IconData i) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withValues(alpha: 0.35))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(i, size: 12, color: c),
            const SizedBox(width: 4),
            Flexible(child: Text(pdT(context, text), maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11, fontWeight: FontWeight.w700, color: c))),
          ]),
        );
    return Wrap(spacing: 4, runSpacing: 4, children: [
      pill(label, color, icon),
      if (row.nonConforme) pill('Non conforme', kPosteRejected, Icons.warning_amber_rounded),
    ]);
  }
}

class PosteFichesSection extends StatelessWidget {
  final Color color;
  final int total;
  final List<PosteFicheRow> rows;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final List<Widget> Function(PosteFicheRow row) actions;
  final Widget? filters;
  final Widget? pagination;
  final VoidCallback? onViewAll;

  const PosteFichesSection({
    super.key,
    required this.color,
    required this.total,
    required this.rows,
    required this.actions,
    this.loading = false,
    this.error,
    this.onRetry,
    this.filters,
    this.pagination,
    this.onViewAll,
  });

  static const _columns = <(String, int)>[('Numéro de fiche', 4), ('Date de production', 3), ('Poste', 2), ('Machine', 2), ('Producteur', 3), ('Quantité produite', 3), ('Statut', 4), ('Actions', 4)];

  Widget _cell(int flex, Widget child) => Expanded(flex: flex, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Align(alignment: Alignment.centerLeft, child: child)));

  Text _value(String text, {bool strong = false}) => Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12.5, fontWeight: strong ? FontWeight.w800 : FontWeight.w500, color: kCrmText));

  Widget _reason(BuildContext context, PosteFicheRow r) => Padding(
        key: ValueKey('poste-fiche-reason-${r.id}'),
        padding: const EdgeInsets.only(top: 6, left: 6, right: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: kPosteRejected),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${pdT(context, 'Motif du refus')} : ${r.rejectionComment ?? '—'}'
              '${r.rejectedAt == null ? '' : ' · ${DateFormat('dd/MM/yyyy HH:mm').format(r.rejectedAt!.toLocal())}'} — ${pdT(context, 'Veuillez corriger la fiche.')}',
              style: tInter(fontSize: 11.5, fontWeight: FontWeight.w600, color: kPosteRejected),
            ),
          ),
        ]),
      );

  String _producer(PosteFicheRow r) {
    final p = r.producer;
    if (p == null || p.isEmpty) return r.operateur ?? '—';
    final at = p.indexOf('@');
    return at > 0 ? p.substring(0, at) : p;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('poste-fiches'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.history_rounded, size: 18, color: color),
            const SizedBox(width: 8),
            Text('${pdT(context, 'Fiches récentes')} ($total)', key: const ValueKey('poste-fiches-title'), style: tInter(fontSize: 14, fontWeight: FontWeight.w800, color: kCrmText)),
          ]),
          if (onViewAll != null)
            TextButton.icon(
              key: const ValueKey('poste-view-all'),
              onPressed: onViewAll,
              style: TextButton.styleFrom(foregroundColor: color),
              icon: const Icon(Icons.list_alt_rounded, size: 16),
              label: Text(pdT(context, 'Voir toutes les fiches')),
            ),
        ]),
        if (filters != null) Padding(padding: const EdgeInsets.only(top: 10), child: filters!),
        const SizedBox(height: 10),
        if (error != null)
          Container(
            key: const ValueKey('poste-fiches-error'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: kPosteRejected.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: kPosteRejected.withValues(alpha: 0.3))),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, size: 18, color: kPosteRejected),
              const SizedBox(width: 8),
              Expanded(child: Text('${pdT(context, 'Erreur de chargement')} : $error', style: tInter(fontSize: 12.5, color: kPosteRejected))),
              if (onRetry != null) TextButton(onPressed: onRetry, child: Text(pdT(context, 'Réessayer'))),
            ]),
          )
        else if (loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (rows.isEmpty)
          Padding(
            key: const ValueKey('poste-fiches-empty'),
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Column(children: [
              Icon(Icons.inbox_outlined, size: 30, color: kCrmTextSub.withValues(alpha: 0.6)),
              const SizedBox(height: 6),
              Text(pdT(context, 'Aucune fiche pour ces filtres'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
            ]),
          )
        else
          LayoutBuilder(builder: (context, c) {
            if (c.maxWidth < 900) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final r in rows)
                  Container(
                    key: ValueKey('poste-fiche-${r.id}'),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: kCrmBorder))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        _value(r.numero ?? '—', strong: true),
                        PosteStatusBadge(r),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        '${pdDate(r.date)} · ${pdT(context, pdPosteLabel(r.poste))} · ${pdT(context, 'Machine')} ${r.machine ?? '—'} · ${_producer(r)} · ${pdQuantity(r.quantity, r.unit)}',
                        style: tInter(fontSize: 12, color: kCrmTextSub),
                      ),
                      if (r.approvalStatus == 'REJECTED') _reason(context, r),
                      Wrap(spacing: 2, children: actions(r)),
                    ]),
                  ),
              ]);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: kCrmBorder)),
                child: Row(children: [
                  for (final (label, flex) in _columns)
                    _cell(flex, Text(pdT(context, label).toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 10.5, fontWeight: FontWeight.w800, color: kCrmTextSub, letterSpacing: 0.5))),
                ]),
              ),
              for (final r in rows)
                Container(
                  key: ValueKey('poste-fiche-${r.id}'),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      _cell(4, _value(r.numero ?? '—', strong: true)),
                      _cell(3, _value(pdDate(r.date))),
                      _cell(2, _value(pdT(context, pdPosteLabel(r.poste)))),
                      _cell(2, _value('${pdT(context, 'Machine')} ${r.machine ?? '—'}')),
                      _cell(3, Tooltip(message: r.producer ?? r.operateur ?? '', child: _value(_producer(r)))),
                      _cell(3, _value(pdQuantity(r.quantity, r.unit), strong: true)),
                      _cell(4, PosteStatusBadge(r)),
                      _cell(4, Wrap(spacing: 0, children: actions(r))),
                    ]),
                    if (r.approvalStatus == 'REJECTED') _reason(context, r),
                  ]),
                ),
            ]);
          }),
        if (pagination != null) Padding(padding: const EdgeInsets.only(top: 10), child: pagination!),
      ]),
    );
  }
}

/// Bouton d'action compact d'une ligne de fiche (icône + infobulle).
class PosteRowAction extends StatelessWidget {
  final String actionKey;
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const PosteRowAction({super.key, required this.actionKey, required this.tooltip, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        key: ValueKey(actionKey),
        tooltip: pdT(context, tooltip),
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 18, color: color),
        onPressed: onTap,
      );
}

/// Liste déroulante compacte des filtres (libellé : valeur).
class PosteFilterDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;
  final Key? fieldKey;
  const PosteFilterDropdown({super.key, this.fieldKey, required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    String text(String v) => label.isEmpty ? pdT(context, v) : '${pdT(context, label)} : ${pdT(context, v)}';
    // Largeur du contenu, bornée par la place disponible (et 300 px) : un
    // libellé long est tronqué, jamais en débordement.
    return LayoutBuilder(builder: (context, c) {
      final max = c.maxWidth.isFinite ? (c.maxWidth < 300 ? c.maxWidth : 300.0) : 300.0;
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: IntrinsicWidth(
          child: Container(
            key: fieldKey,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(9), border: Border.all(color: kCrmBorder)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isDense: true,
                isExpanded: true,
                icon: const Icon(Icons.expand_more_rounded, size: 18, color: kCrmTextSub),
                style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText),
                items: [
                  for (final item in items) DropdownMenuItem<T>(value: item.$1, child: Text(text(item.$2), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Barre de recherche + filtres sur une ligne (passe à la ligne si besoin).
class PosteFiltersBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onSearch;
  final List<Widget> filters;
  const PosteFiltersBar({super.key, required this.hint, required this.onSearch, required this.filters});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SizedBox(
            height: 38,
            child: TextField(
              key: const ValueKey('poste-search'),
              onChanged: onSearch,
              style: tInter(fontSize: 12.5, color: kCrmText),
              decoration: InputDecoration(
                hintText: pdT(context, hint),
                hintStyle: tInter(fontSize: 12.5, color: kCrmTextSub),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: kCrmSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: kCrmBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: kCrmBorder)),
              ),
            ),
          ),
        ),
        ...filters,
      ]);
}

/// Pagination compacte : par page, page courante, précédent / suivant.
class PostePagination extends StatelessWidget {
  final int page;
  final int totalPages;
  final int pageSize;
  final List<int> pageSizes;
  final ValueChanged<int> onPageSize;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  const PostePagination({super.key, required this.page, required this.totalPages, required this.pageSize, required this.pageSizes, required this.onPageSize, this.onPrevious, this.onNext});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(pdT(context, 'Par page :'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
          const SizedBox(width: 8),
          PosteFilterDropdown<int>(label: '', value: pageSize, items: [for (final s in pageSizes) (s, '$s')], onChanged: (v) => onPageSize(v!)),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(key: const ValueKey('poste-page-prev'), icon: const Icon(Icons.chevron_left_rounded), onPressed: onPrevious),
          Text('${pdT(context, 'Page')} $page / $totalPages', key: const ValueKey('poste-page'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
          IconButton(key: const ValueKey('poste-page-next'), icon: const Icon(Icons.chevron_right_rounded), onPressed: onNext),
        ]),
      ]);
}
