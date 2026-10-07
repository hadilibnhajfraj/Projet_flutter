// lib/quality_control/view/quality_control_widgets.dart
//
// Design system du module CONTRÔLE QUALITÉ — tokens du module industriel
// (pipeline_theme / industrial_theme), icônes Material uniquement (jamais
// d'emoji). Couleurs réservées à l'identification : ligne (PROMESH bleu,
// PROBAR orange), statut (vert / rouge / ambre) et action.

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import '../model/quality_control_model.dart';
import '../quality_control_routes.dart';
import '../quality_control_i18n.dart';

// ═══ Tokens ═════════════════════════════════════════════════════════════

// Couleur d'accent du module (distincte de PROMESH/PROBAR/MÉLANGE/MAINTENANCE).
const Color kQualityControlColor = Color(0xFF0EA5E9);
const Color kQcDraftColor = Color(0xFFEAB308); // brouillon : jaune/orange
const Color kQcConformeText = Color(0xFF047857);
const Color kQcNonConformeText = Color(0xFFB91C1C);
const Color kQcAVerifierText = Color(0xFFB45309);

const IconData kQualityControlIcon = Icons.verified_user_outlined;
const IconData kMachineIcon = Icons.precision_manufacturing_outlined;

/// Largeur max du contenu des écrans du module (tableau de bord : plus large
/// que les formulaires industriels pour exploiter l'écran).
const double kQcMaxContentWidth = 1440;
const double kQcRadius = 12;

/// Marge de page responsive.
EdgeInsets qcPagePadding(double width) =>
    width < 600 ? const EdgeInsets.fromLTRB(12, 12, 12, 24) : const EdgeInsets.fromLTRB(24, 16, 24, 32);

Color qualityStatusColor(String status) {
  switch (status) {
    case 'CONFORME':
    case 'VALIDE':
      return kCrmSuccess;
    case 'NON_CONFORME':
      return kCrmDanger;
    case 'EN_COURS':
    case 'EN_ATTENTE':
      return kCrmWarning;
    case 'BROUILLON':
      return kQcDraftColor;
    default:
      return kCrmTextSub;
  }
}

Color qualityToneColor(String tone) => switch (tone) {
      'nok' => kCrmDanger,
      'warn' => kCrmWarning,
      _ => kCrmSuccess,
    };

Color productionTypeColor(String type) => type.toUpperCase() == 'PROBAR' ? kProbarColor : kPromeshColor;

/// PROMESH = treillis/grille ; PROBAR = barres.
IconData productionTypeIcon(String type) =>
    type.toUpperCase() == 'PROBAR' ? Icons.view_week_outlined : Icons.grid_on_rounded;

/// Icône Material par paramètre de la checklist (clé stable en base).
IconData qualityParamIcon(String key) => switch (key) {
      'niveau_bain_graines' => Icons.opacity_rounded,
      'vitesse_tirage' || 'vitesse_tirage_bobinage' || 'vitesse_bobinage' || 'vitesse_alimentation_fibres' || 'vitesse_polymerisation' || 'vitesse_refroidissement' || 'vitesse_coupe' => Icons.speed_rounded,
      'tension_rovings' || 'nombre_rovings' => Icons.line_weight_rounded,
      'variateur_frequence_tirage' || 'variateur_frequence_bobinage' => Icons.tune_rounded,
      'vitesse_barre' || 'promesh4_vitesse_tirage' => Icons.speed_rounded,
      'promesh4_temperature_machine_1_zone_1' ||
      'promesh4_temperature_machine_1_zone_2' ||
      'promesh4_temperature_machine_2_zone_1' ||
      'promesh4_temperature_machine_2_zone_2' =>
        Icons.thermostat_rounded,
      'promesh4_nombre_bobines' => Icons.album_outlined,
      'promesh4_viscosite_bain_1' || 'promesh4_viscosite_bain_2' => Icons.science_outlined,
      'temperature_zone_1' || 'temperature_zone_2' || 'temperature_zone_3' => Icons.thermostat_rounded,
      'pression_air' => Icons.compress_rounded,
      'nombre_bobines' => Icons.album_outlined,
      'alignement_fibres' => Icons.align_horizontal_left_rounded,
      'temperature_zones_chauffage' || 'temperature_filiere' => Icons.thermostat_rounded,
      'pression_impregnation' => Icons.compress_rounded,
      'viscosite_resine' || 'ratio_resine_durcisseur_catalyseur' => Icons.science_outlined,
      'temps_gel' => Icons.hourglass_bottom_rounded,
      'degre_polymerisation' => Icons.percent_rounded,
      'ovalisation' => Icons.panorama_fish_eye_rounded,
      'etat_surface' => Icons.texture_rounded,
      'revetement' => Icons.layers_outlined,
      'longueur_coupe' || 'phys_longueur_coupe' => Icons.straighten_rounded,
      'phys_vitesse_refroidissement' || 'phys_vitesse_coupe' => Icons.speed_rounded,
      'phys_qualite_coupe' => Icons.content_cut_rounded,
      'phys_ceinture_tirage' => Icons.settings_ethernet_rounded,
      'diametre_bar' => Icons.straighten_rounded,
      'temperature_machine' => Icons.thermostat_rounded,
      'temperature_eau' => Icons.device_thermostat_rounded,
      'pression_air_comprime' => Icons.air_rounded,
      'etat_impression' => Icons.print_outlined,
      'nombre_bar_longueur' => Icons.format_list_numbered_rounded,
      'nombre_bar_largeur' => Icons.format_list_numbered_rtl_rounded,
      'dimensions_maille' => Icons.grid_4x4_rounded,
      'dimensions_cote_1_long' => Icons.straighten_rounded,
      'dimensions_cote_2_long' => Icons.straighten_outlined,
      'fuite_eau' => Icons.water_drop_outlined,
      'fuite_air_comprime' => Icons.air_outlined,
      'etat_disque_coupe' => Icons.content_cut_rounded,
      _ => Icons.tune_rounded,
    };

/// "controle_qualite@cbi-tunisia.com" → "controle_qualite" (email complet
/// en infobulle).
String qcControllerLabel(String email) {
  final at = email.indexOf('@');
  final local = at > 0 ? email.substring(0, at) : email;
  // Compte du rôle Contrôle Qualité : nom lisible, jamais l'identifiant
  // technique « controle_qualite » (l'adresse reste en infobulle / détail).
  if (local == 'controle_qualite') return 'Contrôle Qualité';
  return local.isEmpty ? '—' : local;
}

/// Étiquette de la référence d'une fiche (QC-PROMESH-000125 /
/// QC-PROBAR-000087), à la couleur de la ligne : PROMESH bleu, PROBAR orange.
class QcReferenceBadge extends StatelessWidget {
  final String reference;
  final String productionType;
  final bool dense;
  const QcReferenceBadge(this.reference, {super.key, required this.productionType, this.dense = false});

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    final color = productionTypeColor(productionType);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 9 : 12, vertical: dense ? 4 : 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(productionTypeIcon(productionType), size: dense ? 14 : 17, color: color),
        SizedBox(width: dense ? 6 : 8),
        Flexible(
          child: Text(reference,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tInter(fontSize: dense ? 12.5 : 15, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.4)
                  .copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        ),
      ]),
    );
  }
}

/// "30/09/2026" + "17:52:10" → "30/09/2026 17:52".
String qcDateTime(String date, String time) {
  final t = time.length >= 5 ? time.substring(0, 5) : time;
  return [date, t].where((s) => s.isNotEmpty).join(' ');
}

String qcFormatInt(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

// ═══ Statuts ════════════════════════════════════════════════════════════

/// (libellé, couleur de fond/bordure, couleur de texte, icône) par statut.
(String, Color, Color, IconData) qcStatusStyle(String status) => switch (status) {
      'CONFORME' => ('Conforme', kCrmSuccess, kQcConformeText, Icons.check_circle_rounded),
      'NON_CONFORME' => ('Non conforme', kCrmDanger, kQcNonConformeText, Icons.cancel_rounded),
      'EN_ATTENTE' || 'EN_COURS' => ('À vérifier', kCrmWarning, kQcAVerifierText, Icons.schedule_rounded),
      'BROUILLON' => ('Brouillon', kQcDraftColor, const Color(0xFF92400E), Icons.edit_note_rounded),
      'VALIDE' => ('Validé', kCrmSuccess, kQcConformeText, Icons.verified_rounded),
      _ => (status, kCrmTextSub, kCrmTextSub, Icons.help_outline_rounded),
    };

/// Badge de statut (icône + libellé), jamais du texte brut.
class QcStatusBadge extends StatelessWidget {
  final String status;
  final bool dense;
  const QcStatusBadge(this.status, {super.key, this.dense = false});

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    final (label, color, text, icon) = qcStatusStyle(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: dense ? 12 : 14, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(label,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: dense ? 11 : 12, fontWeight: FontWeight.w700, color: text)),
        ),
      ]),
    );
  }
}

/// Compatibilité : ancien nom du badge de statut.
class QualityStatusPill extends QcStatusBadge {
  const QualityStatusPill(super.status, {super.key});
}

/// Pastille de ligne de production (PROMESH bleu / PROBAR orange).
class QcLineChip extends StatelessWidget {
  final String type;
  final bool dense;
  const QcLineChip(this.type, {super.key, this.dense = false});

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    final color = productionTypeColor(type);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 9, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(productionTypeIcon(type), size: dense ? 12 : 14, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(type.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tInter(fontSize: dense ? 10.5 : 11.5, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.3)),
        ),
      ]),
    );
  }
}

// ═══ Structure de page ══════════════════════════════════════════════════

/// Corps de page : fond, largeur max, marges responsives, pull-to-refresh.
class QcPage extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  const QcPage({super.key, required this.children, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          final list = ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: qcPagePadding(c.maxWidth),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: kQcMaxContentWidth),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                ),
              ),
            ],
          );
          return onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list);
        }),
      ),
    );
  }
}

/// Élément du fil d'Ariane du module (chemin null = page courante).
typedef QcCrumb = (String label, String? path);

/// En-tête de page : fil d'Ariane, icône, titre, sous-titre, actions.
class QcPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onBack;
  final Widget? trailing;
  final List<QcCrumb> crumbs;
  final List<Widget> actions;
  final Widget? meta; // ligne de pastilles sous le titre

  const QcPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = kQualityControlIcon,
    this.color = kQualityControlColor,
    this.onBack,
    this.trailing,
    this.crumbs = const [],
    this.actions = const [],
    this.meta,
  });

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    final allActions = [...actions, if (trailing != null) trailing!];
    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 760;
      final heading = Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        if (onBack != null) ...[
          IconButton.outlined(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            tooltip: qcT('Retour'),
            style: IconButton.styleFrom(side: const BorderSide(color: kCrmBorder), foregroundColor: kCrmText),
          ),
          const SizedBox(width: 12),
        ],
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.25)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(kQcRadius),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (crumbs.isNotEmpty) _QcBreadcrumbs(crumbs),
            Text(title, style: tInter(fontSize: narrow ? 19 : 22, fontWeight: FontWeight.w800, color: kCrmText, letterSpacing: -0.2)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle!, style: tInter(fontSize: 13, color: kCrmTextSub)),
              ),
            if (meta != null) Padding(padding: const EdgeInsets.only(top: 8), child: meta!),
          ]),
        ),
        if (!narrow && allActions.isNotEmpty) ...[
          const SizedBox(width: 12),
          // Largeur bornée : les actions passent à la ligne au lieu de déborder.
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: allActions,
            ),
          ),
        ],
      ]);
      if (!narrow || allActions.isEmpty) return Padding(padding: const EdgeInsets.only(bottom: 18), child: heading);
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          heading,
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: allActions),
        ]),
      );
    });
  }
}

class _QcBreadcrumbs extends StatelessWidget {
  final List<QcCrumb> crumbs;
  const _QcBreadcrumbs(this.crumbs);

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    // Chaque élément porte SON chevron à sa droite (élément › suivant) :
    // même après un retour à la ligne, le chevron reste derrière l'élément
    // qu'il suit, jamais en tête de ligne. Sens de lecture forcé de gauche
    // à droite (interface française).
    final children = <Widget>[];
    for (var i = 0; i < crumbs.length; i++) {
      final (label, path) = crumbs[i];
      final last = i == crumbs.length - 1;
      final style = tInter(
        fontSize: 11.5,
        fontWeight: path == null ? FontWeight.w700 : FontWeight.w600,
        color: path == null ? kCrmText : kCrmTextSub,
        letterSpacing: 0.3,
      );
      final text = path == null
          ? Text(label.toUpperCase(), style: style)
          : InkWell(
              onTap: () => context.go(path),
              borderRadius: BorderRadius.circular(4),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1), child: Text(label.toUpperCase(), style: style)),
            );
      children.add(Row(mainAxisSize: MainAxisSize.min, textDirection: TextDirection.ltr, children: [
        Flexible(child: text),
        if (!last)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 3),
            child: Icon(Icons.chevron_right_rounded, size: 14, color: kCrmTextSub, textDirection: TextDirection.ltr),
          ),
      ]));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Wrap(textDirection: TextDirection.ltr, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 2, children: children),
    );
  }
}

/// Panneau (carte de section) : icône, numéro optionnel ("01"), titre,
/// sous-titre, action à droite, contenu.
class QcSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? number;
  final Color color;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsets padding;
  final bool divider;

  const QcSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.subtitle,
    this.number,
    this.color = kQualityControlColor,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    this.divider = false,
  });

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    // Écran étroit : l'action de la section passe sous le titre.
    return LayoutBuilder(builder: (context, c) {
      final stackTrailing = trailing != null && c.maxWidth < 640;
      return _build(stackTrailing);
    });
  }

  Widget _build(bool stackTrailing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: qcCardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, divider ? 12 : 0),
          child: Row(children: [
            if (number != null) ...[
              Text(number!, style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
              const SizedBox(width: 10),
            ],
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: tInter(fontSize: 14.5, fontWeight: FontWeight.w700, color: kCrmText)),
                if (subtitle != null) Text(subtitle!, style: tInter(fontSize: 12, color: kCrmTextSub)),
              ]),
            ),
            if (trailing != null && !stackTrailing) trailing!,
          ]),
        ),
        if (stackTrailing)
          Padding(
            padding: EdgeInsets.fromLTRB(padding.left, 10, padding.right, 0),
            child: Align(alignment: Alignment.centerLeft, child: trailing!),
          ),
        if (divider) const Divider(height: 1, color: kCrmBorder),
        Padding(
          padding: EdgeInsets.fromLTRB(padding.left, divider ? 12 : 14, padding.right, padding.bottom),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ]),
    );
  }
}

BoxDecoration qcCardDecoration({Color? border, Color color = kCrmSurface}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(kQcRadius),
      border: Border.all(color: border ?? kCrmBorder),
      boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 10, offset: Offset(0, 2))],
    );

// ═══ Grilles responsives ════════════════════════════════════════════════

/// Nombre de colonnes d'une grille de cartes selon la largeur disponible.
int qcGridColumns(double width) => width >= 1050 ? 3 : (width >= 680 ? 2 : 1);

/// Grille responsive (Wrap à largeur calculée) — aucune hauteur fixe.
Widget qcGrid(List<Widget> cards, {double gap = 12, int Function(double width)? columns}) =>
    LayoutBuilder(builder: (context, constraints) {
      final cols = (columns ?? qcGridColumns)(constraints.maxWidth).clamp(1, 12);
      final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [for (final c in cards) SizedBox(width: w, child: c)]);
    });

/// Colonnes pour des tuiles d'au moins [minWidth] px (max [max]).
int Function(double) qcColumnsFor(double minWidth, {int max = 6}) =>
    (w) => (w / minWidth).floor().clamp(1, max);

// ═══ Chargement / erreurs / vide ════════════════════════════════════════

/// Bloc squelette pulsé (chargement).
class QcSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const QcSkeleton({super.key, this.width, this.height = 14, this.radius = 6});

  @override
  State<QcSkeleton> createState() => _QcSkeletonState();
}

class _QcSkeletonState extends State<QcSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: const Color(0xFFE9EEF5), borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}

/// Lignes squelette d'une table / liste.
class QcSkeletonRows extends StatelessWidget {
  final int rows;
  final double height;
  const QcSkeletonRows({super.key, this.rows = 4, this.height = 40});

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < rows; i++)
          Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: QcSkeleton(height: height, radius: 8)),
      ]);
}

class QcErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const QcErrorBanner(this.message, {super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kCrmDanger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kCrmDanger.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: kCrmDanger, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: tInter(fontSize: 12.5, color: kQcNonConformeText))),
        if (onRetry != null) TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Réessayer')),
      ]),
    );
  }
}

class QcEmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const QcEmptyState(this.text, {super.key, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Column(children: [
          Icon(icon, size: 30, color: kCrmTextSub.withValues(alpha: 0.6)),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: tInter(fontSize: 12.5, color: kCrmTextSub)),
        ]),
      );
}

class QcReadOnlyNote extends StatelessWidget {
  final String text;
  const QcReadOnlyNote({super.key, this.text = 'Consultation — la saisie des contrôles qualité est réservée au rôle Contrôle Qualité.'});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: kCrmBorder.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.visibility_outlined, size: 16, color: kCrmTextSub),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: tInter(fontSize: 12.5, color: kCrmTextSub))),
        ]),
      );
}

// ═══ Indicateurs ════════════════════════════════════════════════════════

/// Tuile KPI compacte. [value] null = chargement (squelette) ; une valeur
/// indisponible s'affiche "—", jamais un chiffre inventé.
class QcKpiTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final String? caption;
  final Color color;

  const QcKpiTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueWidget,
    this.caption,
    this.color = kQualityControlColor,
  });

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: qcCardDecoration(),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w600, color: kCrmTextSub)),
            const SizedBox(height: 3),
            if (valueWidget != null)
              valueWidget!
            else if (value == null)
              const Padding(padding: EdgeInsets.symmetric(vertical: 3), child: QcSkeleton(width: 56, height: 18))
            else
              Text(value!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 20, fontWeight: FontWeight.w800, color: kCrmText, letterSpacing: -0.3)),
            if (caption != null)
              Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11, color: kCrmTextSub)),
          ]),
        ),
      ]),
    );
  }
}

/// Sélecteur de période compact (Aujourd'hui / Semaine / Mois / Année).
class QcPeriodSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const QcPeriodSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(9), border: Border.all(color: kCrmBorder)),
      child: Wrap(children: [
        for (final (v, label) in kQualityStatsPeriods)
          InkWell(
            onTap: () => onChanged(v),
            borderRadius: BorderRadius.circular(7),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: v == value ? kCrmSurface : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                boxShadow: v == value ? const [BoxShadow(color: Color(0x140F172A), blurRadius: 4, offset: Offset(0, 1))] : null,
              ),
              child: Text(label,
                  style: tInter(fontSize: 12, fontWeight: v == value ? FontWeight.w700 : FontWeight.w500, color: v == value ? kCrmText : kCrmTextSub)),
            ),
          ),
      ]),
    );
  }
}

/// Texture industrielle légère (aucun asset requis) : treillis pour
/// PROMESH, barres pour PROBAR.
class QcLineTexturePainter extends CustomPainter {
  final String type;
  const QcLineTexturePainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1.2;
    if (type.toUpperCase() == 'PROBAR') {
      for (double x = size.width * 0.45; x < size.width + 20; x += 14) {
        canvas.drawRect(Rect.fromLTWH(x, 0, 5, size.height), p..style = PaintingStyle.fill);
      }
    } else {
      p.style = PaintingStyle.stroke;
      const step = 18.0;
      for (double x = size.width * 0.40; x < size.width + step; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      }
      for (double y = 0; y < size.height + step; y += step) {
        canvas.drawLine(Offset(size.width * 0.40, y), Offset(size.width, y), p);
      }
    }
  }

  @override
  bool shouldRepaint(QcLineTexturePainter old) => old.type != type;
}

// ═══ Machines ═══════════════════════════════════════════════════════════

/// Tuile machine compacte (bloc ligne de l'accueil).
class QcMachineTile extends StatelessWidget {
  final String type;
  final String machine;
  final QualityMachineStats? stats;
  final VoidCallback onOpen;
  const QcMachineTile({super.key, required this.type, required this.machine, required this.onOpen, this.stats});

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    final color = productionTypeColor(type);
    final last = stats?.lastControl;
    return Material(
      color: kCrmBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
              child: Icon(kMachineIcon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Machine $machine', style: tInter(fontSize: 13, fontWeight: FontWeight.w700, color: kCrmText)),
                Row(children: [
                  Text(type.toUpperCase(), style: tInter(fontSize: 10.5, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
                  if (last != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: qualityStatusColor(last.isValidated ? last.status : 'BROUILLON'), shape: BoxShape.circle),
                    ),
                  ],
                ]),
              ]),
            ),
            TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(foregroundColor: color, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Ouvrir', style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward_rounded, size: 14, color: color),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Carte machine détaillée (page ligne) : contrôles, dernier contrôle,
/// dernier résultat, ouvrir.
class QcMachineCard extends StatelessWidget {
  final String type;
  final String machine;
  final QualityMachineStats? stats; // null = chargement
  final bool statsUnavailable;
  final VoidCallback onOpen;

  const QcMachineCard({
    super.key,
    required this.type,
    required this.machine,
    required this.onOpen,
    this.stats,
    this.statsUnavailable = false,
  });

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    final color = productionTypeColor(type);
    final last = stats?.lastControl;
    final loading = stats == null && !statsUnavailable;
    Widget metric(IconData icon, String label, Widget value) => Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(children: [
            Icon(icon, size: 14, color: kCrmTextSub),
            const SizedBox(width: 6),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12, color: kCrmTextSub))),
            const SizedBox(width: 8),
            Flexible(child: Align(alignment: Alignment.centerRight, child: value)),
          ]),
        );
    Text strong(String s) =>
        Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText));
    const sk = QcSkeleton(width: 60, height: 12);

    return Material(
      color: kCrmSurface,
      borderRadius: BorderRadius.circular(kQcRadius),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(kQcRadius),
        child: Container(
          decoration: qcCardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(height: 3, color: color),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                    child: Icon(kMachineIcon, size: 20, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Machine $machine', style: tInter(fontSize: 15, fontWeight: FontWeight.w800, color: kCrmText)),
                      Text(type.toUpperCase(), style: tInter(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.4)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                metric(Icons.fact_check_outlined, 'Contrôles qualité',
                    loading ? sk : strong(statsUnavailable ? '—' : qcFormatInt(stats!.counts.total))),
                metric(Icons.calendar_today_outlined, 'Dernier contrôle qualité',
                    loading ? sk : strong(last == null ? 'Aucun' : qcDateTime(last.controlDate, last.controlTime))),
                metric(Icons.check_circle_outline_rounded, 'Statut',
                    loading ? sk : (last == null ? strong('—') : QcStatusBadge(last.isValidated ? last.status : 'BROUILLON', dense: true))),
                const SizedBox(height: 4),
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: onOpen,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('Ouvrir', style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 15, color: color),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══ Table des contrôles ════════════════════════════════════════════════

/// Table professionnelle des contrôles : Date / Heure, Production, Machine,
/// Référence, Résultat, Contrôleur, Actions (+ colonnes étendues pour
/// l'historique). Défilement horizontal sous la largeur minimale.
class QcControlsTable extends StatefulWidget {
  final List<QualityControlModel> controls;
  final bool loading;
  final bool extended;
  final String emptyText;

  const QcControlsTable({
    super.key,
    required this.controls,
    this.loading = false,
    this.extended = false,
    this.emptyText = 'Aucun contrôle qualité pour le moment',
  });

  @override
  State<QcControlsTable> createState() => _QcControlsTableState();
}

class _QcControlsTableState extends State<QcControlsTable> {
  final _hScroll = ScrollController();

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  // (libellé, flex) — largeurs proportionnelles, minimum global ci-dessous.
  List<(String, int)> get _columns => [
        ('Date / Heure', 15),
        ('Ligne', 11),
        ('Machine', 10),
        ('Référence', 19),
        if (widget.extended) ('Poste', 8),
        // Une fiche = UN contrôle, avec un ou plusieurs prélèvements.
        ('Prélèvements', 9),
        if (widget.extended) ('Dernier prélèvement', 10),
        ('Résultat', 13),
        ('Contrôleur qualité', 14),
      ];

  static const _actionsWidth = 100.0;

  double get _minWidth => widget.extended ? 1180 : 940;

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    if (widget.loading && widget.controls.isEmpty) return const QcSkeletonRows(rows: 5, height: 36);
    if (widget.controls.isEmpty) return QcEmptyState(widget.emptyText, icon: Icons.fact_check_outlined);
    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth < _minWidth ? _minWidth : c.maxWidth;
      final table = SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _header(),
          for (var i = 0; i < widget.controls.length; i++) _row(widget.controls[i], i),
        ]),
      );
      if (c.maxWidth >= _minWidth) return table;
      return Scrollbar(
        controller: _hScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _hScroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 10),
          child: table,
        ),
      );
    });
  }

  Widget _cell(int flex, Widget child) => Expanded(
        flex: flex,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Align(alignment: Alignment.centerLeft, child: child)),
      );

  Widget _header() => Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          for (final (label, flex) in _columns) _cell(flex, _headerText(label)),
          SizedBox(width: _actionsWidth, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: _headerText('Actions'))),
        ]),
      );

  Widget _headerText(String label) => Text(label.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: tInter(fontSize: 10.5, fontWeight: FontWeight.w700, color: kCrmTextSub, letterSpacing: 0.5));

  Widget _row(QualityControlModel c, int index) {
    final text = tInter(fontSize: 12.5, color: kCrmText);
    final cols = _columns;
    var i = 0;
    Widget next(Widget child) => _cell(cols[i++].$2, child);
    return InkWell(
      onTap: () => context.go(QcPaths.control(c.id)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
        child: Row(children: [
          next(Text(qcDateTime(c.controlDate, c.controlTime), style: text.copyWith(fontWeight: FontWeight.w600))),
          next(QcLineChip(c.productionType, dense: true)),
          next(Text(c.machineLabel ?? '—', style: text)),
          // Référence de la fiche QUALITÉ.
          next(Text(c.reference.isEmpty ? '—' : c.reference,
              overflow: TextOverflow.ellipsis, style: text.copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]))),
          if (widget.extended) next(Text(c.posteLabel ?? '—', style: text)),
          next(Tooltip(
            message: qcT([
              if (c.readings.isNotEmpty) 'Prélèvements : ${c.readings.map((r) => r.readingTime).join(', ')}',
              if (c.nonConformParameters.isNotEmpty) 'Non conformes : ${c.nonConformParameters.join(', ')}',
            ].join(' — ')),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '${c.readingsCount} prélèvement${c.readingsCount > 1 ? 's' : ''}', style: text),
              if (c.nonConformCount > 0)
                TextSpan(text: '  · ${c.nonConformCount} NC', style: text.copyWith(color: kQcNonConformeText, fontWeight: FontWeight.w700)),
            ]), maxLines: 1, overflow: TextOverflow.ellipsis),
          )),
          if (widget.extended) next(Text(c.lastReadingTime ?? '—', style: text.copyWith(fontWeight: FontWeight.w600))),
          // Brouillon tant que la fiche n'est pas validée ; sinon son résultat.
          next(QcStatusBadge(c.isValidated ? c.status : 'BROUILLON', dense: true)),
          next(Tooltip(message: c.controllerEmail, child: Text(qcControllerLabel(c.controllerEmail), overflow: TextOverflow.ellipsis, style: text))),
          SizedBox(
            width: _actionsWidth,
            child: Row(children: [
              IconButton(
                tooltip: qcT('Voir'),
                visualDensity: VisualDensity.compact,
                onPressed: () => context.go(QcPaths.control(c.id)),
                icon: const Icon(Icons.visibility_outlined, size: 18, color: kCrmTextSub),
              ),
              _moreMenu(c),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _moreMenu(QualityControlModel c) => PopupMenuButton<String>(
        tooltip: qcT('Plus'),
        icon: const Icon(Icons.more_horiz_rounded, size: 18, color: kCrmTextSub),
        position: PopupMenuPosition.under,
        onSelected: (v) {
          switch (v) {
            case 'open':
              context.go(QcPaths.control(c.id));
            case 'machine':
              if (c.machine != null) context.go(QcPaths.machine(c.productionType, c.machine!));
            case 'line':
              context.go(QcPaths.line(c.productionType));
            case 'copy':
              Clipboard.setData(ClipboardData(text: c.reference));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Référence copiée')));
          }
        },
        itemBuilder: (_) => [
          _menuItem('open', Icons.open_in_new_rounded, 'Ouvrir le contrôle qualité'),
          if (c.machine != null) _menuItem('machine', kMachineIcon, 'Ouvrir ${c.machineLabel ?? 'la machine'}'),
          _menuItem('line', productionTypeIcon(c.productionType), 'Voir la ligne ${c.productionType}'),
          if (c.reference.isNotEmpty) _menuItem('copy', Icons.copy_rounded, 'Copier la référence'),
        ],
      );

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) => PopupMenuItem(
        value: value,
        height: 40,
        child: Row(children: [
          Icon(icon, size: 18, color: kCrmTextSub),
          const SizedBox(width: 10),
          Text(label, style: tInter(fontSize: 13, color: kCrmText)),
        ]),
      );
}
