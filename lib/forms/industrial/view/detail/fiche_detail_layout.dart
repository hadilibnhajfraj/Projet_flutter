// lib/forms/industrial/view/detail/fiche_detail_layout.dart
//
// Système de design du DÉTAIL d'une fiche de production, commun à PROMESH
// (PorPromeshDetailScreen) et PROBAR (ProbarDetailScreen) : en-tête avec
// actions, bannière de verrouillage, barre de résumé, panneaux Informations
// générales / Production / Contrôle qualité, onglets de détail, tableau et
// historique. Composants de PRÉSENTATION uniquement : ils affichent les
// valeurs que l'écran leur passe (données de la fiche) et appellent ses
// callbacks — aucune règle métier, aucun appel réseau, aucune route (fichier
// sans dépendance web, testable hors navigateur). Une valeur absente
// s'affiche « — », jamais une valeur inventée.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/industrial/view/poste_dashboard_layout.dart' show pdT, kPosteAccepted, kPostePending, kPosteRejected, kPosteNeutral;
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';

const Color kFicheSubmitted = Color(0xFF0891B2); // soumise : cyan
const Color kFicheLocked = Color(0xFF7F1D1D);
const Color kFicheTitle = Color(0xFF0F172A); // bleu nuit
const double _radius = 14;

BoxDecoration ficheCard() => BoxDecoration(
      color: kCrmSurface,
      borderRadius: BorderRadius.circular(_radius),
      border: Border.all(color: kCrmBorder),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
    );

String fdValue(Object? v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? '—' : s;
}

String fdDateTime(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  return d == null ? fdValue(iso) : DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
}

String fdDate(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  return d == null ? fdValue(iso) : DateFormat('dd/MM/yyyy').format(d);
}

/// « 11:13:26 » → « 11:13 » ; tout autre texte est conservé tel quel.
String fdTime(String? v) {
  final t = (v ?? '').trim();
  final m = RegExp(r'^(\d{1,2}):(\d{2})(:\d{2})?$').firstMatch(t);
  return m == null ? t : '${m.group(1)!.padLeft(2, '0')}:${m.group(2)}';
}

/// Plage horaire ; une seule heure si début = fin ; « — » si aucune.
String fdHours(String? start, String? end) {
  final a = fdTime(start);
  final b = fdTime(end);
  if (a.isEmpty && b.isEmpty) return '—';
  if (a.isEmpty || a == b) return a.isEmpty ? b : a;
  if (b.isEmpty) return a;
  return '$a – $b';
}

/// Mesure saisie : nombre nettoyé (« 151.00 » → « 151 », « 0 » reste
/// « 0 »), texte conservé, absente → « — » (jamais un zéro inventé).
String fdMeasure(Object? v, [String unit = '']) {
  final t = v?.toString().trim() ?? '';
  if (t.isEmpty) return '—';
  final n = num.tryParse(t.replaceAll(',', '.'));
  return '${n == null ? t : fdNumber(n)}$unit';
}

String fdNumber(num? v) {
  if (v == null || (v is double && v.isNaN)) return '—';
  if (v == v.roundToDouble()) return NumberFormat('#,##0', 'fr_FR').format(v);
  return NumberFormat('#,##0.##', 'fr_FR').format(v);
}

// ═══ Statuts ═════════════════════════════════════════════════════════════

/// Statut affiché d'une fiche : un seul badge principal, selon les statuts
/// réels — brouillon (saisie en cours), puis décision de validation si la
/// fiche est dans le circuit, sinon « Soumise » (saisie terminée).
({String label, Color color, IconData icon}) ficheStatus({required bool isDraft, String? approvalStatus}) {
  if (isDraft) return (label: 'Brouillon', color: kPosteNeutral, icon: Icons.edit_note_rounded);
  return switch (approvalStatus) {
    'PENDING' => (label: 'En attente', color: kPostePending, icon: Icons.hourglass_top_rounded),
    'APPROVED' => (label: 'Acceptée', color: kPosteAccepted, icon: Icons.verified_outlined),
    'REJECTED' => (label: 'Refusée', color: kPosteRejected, icon: Icons.block_rounded),
    _ => (label: 'Soumise', color: kFicheSubmitted, icon: Icons.send_rounded),
  };
}

class FicheBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const FicheBadge({super.key, required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.35))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(child: Text(pdT(context, label), maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w700, color: color))),
        ]),
      );
}

// ═══ En-tête ═════════════════════════════════════════════════════════════

class FicheAction {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap; // null : désactivée
  final String? disabledReason;
  const FicheAction(this.key, {required this.label, required this.icon, required this.color, this.onTap, this.disabledReason});
}

class FicheDetailHeader extends StatelessWidget {
  final String title; // « Fiche de production PROMESH »
  final Color color;
  final String? numero;
  final List<Widget> badges;
  final List<(IconData, String)> meta; // date, heure, machine, poste
  final VoidCallback onBack;
  final List<FicheAction> actions;

  const FicheDetailHeader({super.key, required this.title, required this.color, this.numero, this.badges = const [], this.meta = const [], required this.onBack, this.actions = const []});

  Widget _action(BuildContext context, FicheAction a) {
    final enabled = a.onTap != null;
    final c = enabled ? a.color : kCrmTextSub.withValues(alpha: 0.5);
    final button = OutlinedButton.icon(
      key: ValueKey('fiche-action-${a.key}'),
      onPressed: a.onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: c,
        side: BorderSide(color: enabled ? a.color.withValues(alpha: 0.35) : kCrmBorder),
        backgroundColor: enabled ? a.color.withValues(alpha: 0.05) : kCrmBg,
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      icon: Icon(a.icon, size: 16, color: c),
      label: Text(pdT(context, a.label), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: c)),
    );
    if (enabled || a.disabledReason == null) return button;
    return Tooltip(message: pdT(context, a.disabledReason!), child: button);
  }

  @override
  Widget build(BuildContext context) {
    final identity = Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      // Même hauteur et même style que les boutons d'action (alignés).
      OutlinedButton.icon(
        key: const ValueKey('fiche-back'),
        onPressed: onBack,
        style: OutlinedButton.styleFrom(
          foregroundColor: kCrmText,
          side: const BorderSide(color: kCrmBorder),
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        icon: const Icon(Icons.arrow_back_rounded, size: 16, color: kCrmTextSub),
        label: Text(pdT(context, 'Retour'), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText)),
      ),
      const SizedBox(width: 12),
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(Icons.description_outlined, color: color, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(pdT(context, title), key: const ValueKey('fiche-title'), style: tInter(fontSize: 19, fontWeight: FontWeight.w900, color: kFicheTitle, height: 1.2)),
            if (numero != null) Text(numero!, key: const ValueKey('fiche-numero'), style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            ...badges,
          ]),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 16, runSpacing: 4, children: [
              for (final (icon, text) in meta)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 14, color: kCrmTextSub),
                  const SizedBox(width: 5),
                  Text(text, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmTextSub)),
                ]),
            ]),
          ],
        ]),
      ),
    ]);
    Widget buttons(WrapAlignment align) => Wrap(spacing: 8, runSpacing: 8, alignment: align, children: [for (final a in actions) _action(context, a)]);
    return Container(
      key: const ValueKey('fiche-header'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: ficheCard(),
      child: LayoutBuilder(builder: (context, c) {
        // Grand écran : actions à droite ; petit écran : sous l'identité.
        if (c.maxWidth >= 1000) {
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: identity), const SizedBox(width: 16), ConstrainedBox(constraints: BoxConstraints(maxWidth: c.maxWidth * 0.5), child: buttons(WrapAlignment.end))]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [identity, const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: buttons(WrapAlignment.start))]);
      }),
    );
  }
}

/// Bannière compacte : raison du verrouillage (aucune action possible).
class FicheLockBanner extends StatelessWidget {
  final String message;
  const FicheLockBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('fiche-locked'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: kFicheLocked.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: kFicheLocked.withValues(alpha: 0.30))),
        child: Row(children: [
          const Icon(Icons.lock_rounded, size: 16, color: kFicheLocked),
          const SizedBox(width: 8),
          Expanded(child: Text(pdT(context, message), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kFicheLocked))),
        ]),
      );
}

// ═══ Résumé ══════════════════════════════════════════════════════════════

class FicheSummaryItem {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const FicheSummaryItem(this.icon, this.label, this.value, {this.color});
}

/// Barre horizontale à séparateurs discrets ; plusieurs lignes si étroit.
class FicheSummaryBar extends StatelessWidget {
  final List<FicheSummaryItem> items;
  const FicheSummaryBar({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    Widget item(FicheSummaryItem i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(i.icon, size: 18, color: i.color ?? kCrmTextSub),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(pdT(context, i.label), style: tInter(fontSize: 10.5, fontWeight: FontWeight.w600, color: kCrmTextSub)),
              Text(i.value, style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: i.color ?? kFicheTitle)),
            ]),
          ]),
        );
    return Container(
      key: const ValueKey('fiche-summary'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: ficheCard(),
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (var k = 0; k < items.length; k++) ...[
          if (k > 0) Container(width: 1, height: 30, color: kCrmBorder),
          item(items[k]),
        ],
      ]),
    );
  }
}

// ═══ Panneaux ════════════════════════════════════════════════════════════

class FichePanel extends StatelessWidget {
  final String panelKey;
  final IconData icon;
  final String title;
  final Color color;
  final Widget child;
  const FichePanel({super.key, required this.panelKey, required this.icon, required this.title, required this.color, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        key: ValueKey('fiche-panel-$panelKey'),
        padding: const EdgeInsets.all(14),
        decoration: ficheCard(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(pdT(context, title), style: tInter(fontSize: 14, fontWeight: FontWeight.w800, color: kFicheTitle))),
          ]),
          const SizedBox(height: 10),
          child,
        ]),
      );
}

/// Libellé / valeur en deux colonnes (une seule sur écran étroit).
class FicheInfoGrid extends StatelessWidget {
  final List<(String, String)> entries;
  const FicheInfoGrid({super.key, required this.entries});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 520 ? 2 : 1;
        final w = (c.maxWidth - (cols - 1) * 16) / cols;
        return Wrap(spacing: 16, children: [
          for (final (label, value) in entries)
            SizedBox(
              width: w,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 130, child: Text(pdT(context, label), style: tInter(fontSize: 12, color: kCrmTextSub))),
                  Expanded(child: Text(value, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText))),
                ]),
              ),
            ),
        ]);
      });
}

/// Production : quantité principale en grand + mesures complémentaires.
class FicheProductionPanel extends StatelessWidget {
  final Color color;
  final String label;
  final num? quantity;
  final String unit;
  final List<(String, String)> extras;
  const FicheProductionPanel({super.key, required this.color, required this.label, required this.quantity, required this.unit, this.extras = const []});

  @override
  Widget build(BuildContext context) => FichePanel(
        panelKey: 'production',
        icon: Icons.speed_rounded,
        title: 'Production',
        color: color,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(pdT(context, label), style: tInter(fontSize: 12, color: kCrmTextSub)),
          const SizedBox(height: 2),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Flexible(child: Text(fdNumber(quantity), key: const ValueKey('fiche-production-value'), style: tInter(fontSize: 32, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5))),
            if (quantity != null) ...[const SizedBox(width: 6), Text(unit, key: const ValueKey('fiche-production-unit'), style: tInter(fontSize: 15, fontWeight: FontWeight.w800, color: color))],
          ]),
          if (extras.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final (l, v) in extras)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(9), border: Border.all(color: kCrmBorder)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(pdT(context, l), style: tInter(fontSize: 10.5, color: kCrmTextSub)),
                    Text(v, style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText)),
                  ]),
                ),
            ]),
          ],
        ]),
      );
}

/// Contrôle qualité : résultat global et répartition des mesures réelles.
class FicheQualityPanel extends StatelessWidget {
  /// Résultat global enregistré sur la fiche (true conforme, false non
  /// conforme, null non renseigné).
  final bool? globalConforme;
  final int conformes;
  final int aVerifier;
  final int nonConformes;
  final String? note;
  const FicheQualityPanel({super.key, this.globalConforme, this.conformes = 0, this.aVerifier = 0, this.nonConformes = 0, this.note});

  @override
  Widget build(BuildContext context) {
    final measures = conformes + aVerifier + nonConformes;
    Widget stat(String key, String label, int n, Color c) => Expanded(
          child: Container(
            key: ValueKey('fiche-quality-$key'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(9), border: Border.all(color: c.withValues(alpha: 0.25))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$n', style: tInter(fontSize: 20, fontWeight: FontWeight.w900, color: c)),
              Text(pdT(context, label), maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11, fontWeight: FontWeight.w600, color: kCrmTextSub)),
            ]),
          ),
        );
    return FichePanel(
      panelKey: 'quality',
      icon: Icons.verified_user_outlined,
      title: 'Contrôle qualité',
      color: kPosteAccepted,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (globalConforme != null)
          FicheBadge(
            label: globalConforme! ? 'Conforme' : 'Non conforme',
            color: globalConforme! ? kPosteAccepted : kPosteRejected,
            icon: globalConforme! ? Icons.check_circle_rounded : Icons.cancel_rounded,
          ),
        if (measures > 0) ...[
          if (globalConforme != null) const SizedBox(height: 10),
          Row(children: [
            stat('ok', 'Conforme', conformes, kPosteAccepted),
            const SizedBox(width: 8),
            stat('check', 'À vérifier', aVerifier, kPostePending),
            const SizedBox(width: 8),
            stat('nok', 'Non conforme', nonConformes, kPosteRejected),
          ]),
        ],
        if (globalConforme == null && measures == 0)
          Text(pdT(context, 'Aucun résultat de contrôle qualité enregistré'), key: const ValueKey('fiche-quality-empty'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
        if (note != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(pdT(context, note!), style: tInter(fontSize: 11, color: kCrmTextSub))),
      ]),
    );
  }
}

/// Deux panneaux côte à côte sur grand écran, empilés sinon.
class FicheRow extends StatelessWidget {
  final List<Widget> children;
  final double breakpoint;
  const FicheRow({super.key, required this.children, this.breakpoint = 900});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < breakpoint) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < children.length; i++) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 12), child: children[i]),
            ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: children[i])],
          ]);
        }),
      );
}

// ═══ Onglets ═════════════════════════════════════════════════════════════

class FicheTab {
  final String key;
  final String label;
  final IconData icon;
  final int? count;
  final Widget Function() builder;
  const FicheTab(this.key, {required this.label, required this.icon, this.count, required this.builder});
}

class FicheDetailTabs extends StatefulWidget {
  final List<FicheTab> tabs;
  final Color color;
  const FicheDetailTabs({super.key, required this.tabs, required this.color});

  @override
  State<FicheDetailTabs> createState() => _FicheDetailTabsState();
}

class _FicheDetailTabsState extends State<FicheDetailTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tab = widget.tabs[_index.clamp(0, widget.tabs.length - 1)];
    return Container(
      key: const ValueKey('fiche-tabs'),
      decoration: ficheCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Barre d'onglets défilante (jamais de débordement sur mobile).
        Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              for (var i = 0; i < widget.tabs.length; i++)
                InkWell(
                  key: ValueKey('fiche-tab-${widget.tabs[i].key}'),
                  onTap: () => setState(() => _index = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: i == _index ? widget.color : Colors.transparent, width: 2.5))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(widget.tabs[i].icon, size: 16, color: i == _index ? widget.color : kCrmTextSub),
                      const SizedBox(width: 6),
                      Text(pdT(context, widget.tabs[i].label), style: tInter(fontSize: 12.5, fontWeight: i == _index ? FontWeight.w800 : FontWeight.w600, color: i == _index ? kFicheTitle : kCrmTextSub)),
                      if (widget.tabs[i].count != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: (i == _index ? widget.color : kCrmTextSub).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                          child: Text('${widget.tabs[i].count}', style: tInter(fontSize: 10.5, fontWeight: FontWeight.w800, color: i == _index ? widget.color : kCrmTextSub)),
                        ),
                      ],
                    ]),
                  ),
                ),
            ]),
          ),
        ),
        Padding(key: ValueKey('fiche-tab-content-${tab.key}'), padding: const EdgeInsets.all(14), child: tab.builder()),
      ]),
    );
  }
}

/// Sous-titre d'un bloc dans un onglet.
class FicheSubheading extends StatelessWidget {
  final String text;
  final IconData icon;
  const FicheSubheading(this.text, {super.key, required this.icon});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Row(children: [
          Icon(icon, size: 15, color: kCrmTextSub),
          const SizedBox(width: 6),
          Text(pdT(context, text), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: kFicheTitle)),
        ]),
      );
}

/// État vide explicite d'un onglet ou d'un bloc.
class FicheEmpty extends StatelessWidget {
  final String text;
  final IconData icon;
  const FicheEmpty(this.text, {super.key, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(children: [
          Icon(icon, size: 28, color: kCrmTextSub.withValues(alpha: 0.55)),
          const SizedBox(height: 6),
          Text(pdT(context, text), textAlign: TextAlign.center, style: tInter(fontSize: 12.5, color: kCrmTextSub)),
        ]),
      );
}

/// Tableau à en-têtes lisibles et colonnes alignées ; défilement
/// horizontal sous [minWidth].
class FicheTable extends StatelessWidget {
  final String tableKey;
  final List<(String, int)> columns; // libellé, flex
  final List<List<Widget>> rows;
  final double minWidth;
  final String emptyMessage;
  const FicheTable({super.key, required this.tableKey, required this.columns, required this.rows, this.minWidth = 560, this.emptyMessage = 'Aucune donnée enregistrée'});

  static Widget text(String v, {bool strong = false, Color color = kCrmText}) => Text(v, style: tInter(fontSize: 12.5, fontWeight: strong ? FontWeight.w800 : FontWeight.w500, color: color));

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return FicheEmpty(emptyMessage);
    Widget cell(int flex, Widget child) => Expanded(flex: flex, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Align(alignment: Alignment.centerLeft, child: child)));
    final table = Column(key: ValueKey('fiche-table-$tableKey'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: kCrmBorder)),
        child: Row(children: [
          for (final (label, flex) in columns) cell(flex, Text(pdT(context, label).toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 10.5, fontWeight: FontWeight.w800, color: kCrmTextSub, letterSpacing: 0.5))),
        ]),
      ),
      for (var r = 0; r < rows.length; r++)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: r.isOdd ? kCrmBg.withValues(alpha: 0.5) : null, border: const Border(bottom: BorderSide(color: kCrmBorder))),
          child: Row(children: [for (var c = 0; c < columns.length; c++) cell(columns[c].$2, rows[r][c])]),
        ),
    ]);
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= minWidth) return table;
      return SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: minWidth, child: table));
    });
  }
}

/// Grille de valeurs (paramètres machine, personnel) : libellé + valeur.
class FicheValueGrid extends StatelessWidget {
  final List<(String, String, Color?)> values;
  final double minTileWidth;
  const FicheValueGrid({super.key, required this.values, this.minTileWidth = 200});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = (c.maxWidth / minTileWidth).floor().clamp(1, 4);
        final w = (c.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (label, value, color) in values)
            SizedBox(
              width: w,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(9), border: Border.all(color: kCrmBorder)),
                child: Row(children: [
                  // Accent d'état (couleur de la valeur), barre intérieure.
                  Container(width: 3, height: 30, decoration: BoxDecoration(color: color ?? kCrmBorder, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(pdT(context, label), maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 10.5, color: kCrmTextSub)),
                      Text(value, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: color ?? kCrmText)),
                    ]),
                  ),
                ]),
              ),
            ),
        ]);
      });
}

/// Encadré de texte (observation, justification, motif).
class FicheNote extends StatelessWidget {
  final String label;
  final String text;
  final Color color;
  const FicheNote({super.key, required this.label, required this.text, this.color = kCrmTextSub});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(9), border: Border.all(color: color.withValues(alpha: 0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(pdT(context, label), style: tInter(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(text, style: tInter(fontSize: 12.5, color: kCrmText, height: 1.4)),
        ]),
      );
}

/// Rôles du personnel d'une fiche (clés identiques PROMESH / PROBAR).
const kFichePersonnelRoles = [
  ('responsable1', 'Responsable 1'),
  ('responsable2', 'Responsable 2'),
  ('operateur1', 'Opérateur 1'),
  ('operateur2', 'Opérateur 2'),
  ('aideOperateur', 'Aide Opérateur'),
  ('manoeuvre', 'Manœuvre'),
  ('stagiaire1', 'Stagiaire 1'),
  ('stagiaire2', 'Stagiaire 2'),
];

/// Badge de statut d'une mesure qualité (C / NC / sans statut).
Widget ficheMeasureStatus(String? code) => switch (code) {
      'C' => const FicheBadge(label: 'Conforme', color: kPosteAccepted, icon: Icons.check_circle_rounded),
      'NC' => const FicheBadge(label: 'Non conforme', color: kPosteRejected, icon: Icons.cancel_rounded),
      _ => const FicheBadge(label: 'À vérifier', color: kPostePending, icon: Icons.help_outline_rounded),
    };

// ═══ Historique ══════════════════════════════════════════════════════════

class FicheHistoryEntry {
  final IconData icon;
  final Color color;
  final String title;
  final String? detail;
  final String when;
  const FicheHistoryEntry({required this.icon, required this.color, required this.title, this.detail, required this.when});
}

class FicheHistoryTimeline extends StatelessWidget {
  final List<FicheHistoryEntry> entries;
  const FicheHistoryTimeline({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const FicheEmpty('Aucun historique disponible', icon: Icons.history_rounded);
    return Column(key: const ValueKey('fiche-history'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < entries.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Column(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: entries[i].color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(entries[i].icon, size: 15, color: entries[i].color),
              ),
              if (i < entries.length - 1) Expanded(child: Container(width: 2, color: kCrmBorder)),
            ]),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14, top: 3),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(pdT(context, entries[i].title), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: kFicheTitle)),
                    Text(entries[i].when, style: tInter(fontSize: 11.5, color: kCrmTextSub)),
                  ]),
                  if (entries[i].detail != null) Text(entries[i].detail!, style: tInter(fontSize: 12, color: kCrmTextSub)),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}
