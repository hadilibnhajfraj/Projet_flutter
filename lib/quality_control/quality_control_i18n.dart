// lib/quality_control/quality_control_i18n.dart
//
// CONTRÔLE QUALITÉ — français / anglais.
//
// Le module est écrit en français (langue source). Quand la langue de
// l'application n'est pas le français, chaque texte affiché est traduit ici :
// - `Text` (ci-dessous) remplace le `Text` de Flutter dans les fichiers du
//   module (import `material.dart` avec `hide Text`) : tout texte affiché est
//   traduit automatiquement, sans modifier les écrans ;
// - `qcT('…')` traduit les textes qui ne passent pas par un `Text`
//   (indications de champ, infobulles, titres des sélecteurs…).
// Traduction : correspondance exacte (`_exact`), puis modèles à valeurs
// variables (`_templates` — « {} prélèvements » → « {0} samples »), les valeurs
// étant elles-mêmes traduites. Les libellés servis par le backend
// (paramètres, catégories, messages) sont traduits de la même façon.
// Un texte sans traduction est affiché tel quel et noté dans
// `QcI18n.missing` (contrôlé par les tests).

import 'package:flutter/material.dart' as m;
import 'package:flutter/widgets.dart';

class QcI18n {
  QcI18n._();

  /// Code de langue de l'application ('fr', 'en'…) — tenu à jour par
  /// AppLanguageProvider. Français : texte source ; toute autre langue :
  /// anglais.
  static final ValueNotifier<String> language = ValueNotifier<String>('fr');

  static bool get isFrench => language.value == 'fr';

  /// Textes affichés sans traduction (langue ≠ français) — tests.
  static final Set<String> missing = <String>{};

  static final RegExp _french = RegExp(
    r"[àâäçéèêëîïôöùûüœ]|\b(le|la|les|des|du|une|et|pour|par|sur|aucun|aucune|avec|est|sont|prélèvements?|fiches?|contrôles?|étapes?)\b",
    caseSensitive: false,
  );

  /// Textes FRANÇAIS affichés sans traduction alors que la langue n'est pas
  /// le français (les données — adresses, références, valeurs — sont ignorées).
  static List<String> frenchResidue() => missing.where(_french.hasMatch).toList()..sort();

  /// À appeler dans `build` : le widget est reconstruit quand la langue de
  /// l'application change.
  static void watch(BuildContext context) => Localizations.maybeLocaleOf(context);
}

final RegExp _letters = RegExp(r'[A-Za-zÀ-ÿ]{2}');

/// Traduit un texte du module selon la langue de l'application.
String qcT(String text) {
  if (QcI18n.isFrench || text.isEmpty || !_letters.hasMatch(text)) return text;
  return _translate(text, 0) ?? _miss(text);
}

String _miss(String text) {
  QcI18n.missing.add(text);
  return text;
}

String? _translate(String text, int depth) {
  final exact = _exact[text] ?? _upper[text];
  if (exact != null) return exact;
  if (depth > 3) return null;
  for (final t in _templates) {
    final match = t.pattern.firstMatch(text);
    if (match == null) continue;
    var out = t.en;
    for (var i = 0; i < match.groupCount; i++) {
      final value = match.group(i + 1) ?? '';
      // Une valeur variable peut elle-même être un texte du module.
      out = out.replaceAll('{$i}', _letters.hasMatch(value) ? (_translate(value, depth + 1) ?? value) : value);
    }
    return out;
  }
  return null;
}

/// `Text` du module : même usage que celui de Flutter, texte traduit.
class Text extends StatelessWidget {
  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;
  final TextDirection? textDirection;

  const Text(String this.data, {super.key, this.style, this.maxLines, this.overflow, this.textAlign, this.softWrap, this.textDirection}) : textSpan = null;

  const Text.rich(InlineSpan this.textSpan, {super.key, this.style, this.maxLines, this.overflow, this.textAlign, this.softWrap, this.textDirection})
      : data = null;

  static InlineSpan _span(InlineSpan span) {
    if (span is! TextSpan) return span;
    return TextSpan(
      text: span.text == null ? null : qcT(span.text!),
      style: span.style,
      recognizer: span.recognizer,
      children: span.children?.map(_span).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context);
    if (data != null) {
      return m.Text(qcT(data!), style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign, softWrap: softWrap, textDirection: textDirection);
    }
    return m.Text.rich(
      QcI18n.isFrench ? textSpan! : _span(textSpan!),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: softWrap,
      textDirection: textDirection,
    );
  }
}

// ── Modèles à valeurs variables ──────────────────────────────────────────

class _Template {
  final RegExp pattern;
  final String en;
  const _Template(this.pattern, this.en);
}

/// « {} prélèvements » ↔ « {0} samples » : chaque `{}` du français devient un
/// groupe ; `{n}` dans l'anglais reprend le n-ième.
_Template _tpl(String fr, String en) {
  final parts = fr.split('{}');
  final buffer = StringBuffer('^');
  for (var i = 0; i < parts.length; i++) {
    buffer.write(RegExp.escape(parts[i]));
    if (i < parts.length - 1) buffer.write(i == parts.length - 2 && parts.last.isEmpty ? '(.*)' : '(.*?)');
  }
  buffer.write(r'$');
  return _Template(RegExp(buffer.toString(), dotAll: true), en);
}

final Map<String, String> _upper = {for (final e in _exact.entries) e.key.toUpperCase(): e.value.toUpperCase()};

// ── Dictionnaire français → anglais ──────────────────────────────────────

const Map<String, String> _exact = {
  // Module, navigation
  "Contrôle Qualité": "Quality Control",
  "Contrôle qualité": "Quality control",
  "Tableau de bord": "Dashboard",
  "Historique": "History",
  "Comparaison qualité": "Quality comparison",
  "Retour": "Back",
  "Réessayer": "Retry",
  "Rechercher": "Search",
  "Recherche": "Search",
  "Rechercher un contrôle qualité, une référence QC, une machine...": "Search a quality control, a QC reference, a machine...",
  "Annuler": "Cancel",
  "Valider": "Confirm",
  "Ouvrir": "Open",
  "Voir": "View",
  "Plus": "More",
  "Tout voir": "View all",
  "Tout": "All",
  "Tous": "All",
  "Toutes": "All",
  "Aucun": "None",
  "Aucune": "None",
  "Chargement…": "Loading…",
  "Effacer": "Clear",
  "Réinitialiser": "Reset",
  "Période": "Period",
  "Page précédente": "Previous page",
  "Page suivante": "Next page",
  "Enregistrer": "Save",
  "Enregistrement…": "Saving…",
  "Supprimer": "Delete",
  "Modifier": "Edit",
  "Consulter": "View",
  "Actions": "Actions",

  // Statuts
  "Conforme": "Compliant",
  "Non conforme": "Non-compliant",
  "Non contrôlé": "Not checked",
  "À vérifier": "To verify",
  "À VÉRIFIER": "TO VERIFY",
  "EN COURS": "IN PROGRESS",
  "NON CONFORME": "NON-COMPLIANT",
  "Brouillon": "Draft",
  "brouillons": "drafts",
  "Validé": "Validated",
  "Lecture seule": "Read only",
  "Conformes": "Compliant",
  "Non conformes": "Non-compliant",
  "Statut": "Status",
  "Résultat": "Result",

  // Périodes, postes
  "Aujourd'hui": "Today",
  "Cette semaine": "This week",
  "Ce mois": "This month",
  "Cette année": "This year",
  "Matin": "Morning",
  "Soir": "Evening",
  "Nuit": "Night",

  // Tableau de bord / lignes / machines
  "Suivez les contrôles qualité PROMESH et PROBAR et accédez rapidement aux machines.": "Track PROMESH and PROBAR quality controls and reach the machines quickly.",
  "Derniers contrôles qualité": "Latest quality controls",
  "Vos contrôles qualité les plus récents, toutes lignes": "Your most recent quality controls, all lines",
  "Contrôles qualité les plus récents, toutes lignes": "Most recent quality controls, all lines",
  "Tout l'historique": "Full history",
  "Aucune machine configurée": "No machine configured",
  "Voir la ligne": "View line",
  "Nouveau contrôle qualité": "New Quality Control",
  "Taux de conformité (contrôles qualité validés)": "Compliance rate (validated quality controls)",
  "Aucun contrôle qualité": "No quality control",
  "Statistiques générales": "General statistics",
  "Total contrôles qualité": "Total quality controls",
  "Contrôles qualité": "Quality controls",
  "Prélèvements": "Samples",
  "Prélèvement": "Sample",
  "dans ces contrôles qualité": "in these quality controls",
  "Machines actives": "Active machines",
  "Machines": "Machines",
  "Machine": "Machine",
  "au moins un contrôle qualité": "at least one quality control",
  "RÉPARTITION PAR LIGNE": "BREAKDOWN BY LINE",
  "Actions rapides": "Quick actions",
  "Consultation seule — la saisie est réservée au rôle Contrôle Qualité.": "Read only — data entry is reserved for the Quality Control role.",
  "Consultation — la saisie des contrôles qualité est réservée au rôle Contrôle Qualité.": "Read only — quality control entry is reserved for the Quality Control role.",
  "Choisir la machine — nouvelle fiche qualité": "Choose the machine — new quality sheet",
  "Historique complet": "Full history",
  "Rechercher et filtrer les contrôles qualité": "Search and filter quality controls",
  "Choisissez la machine : une nouvelle fiche qualité sera créée pour elle.": "Choose the machine: a new quality sheet will be created for it.",
  "Choisissez une machine pour consulter ou créer un contrôle qualité.": "Choose a machine to view or create a quality control.",
  "Fiches de contrôle qualité de cette machine — créez une nouvelle fiche ou ouvrez une fiche existante.":
      "Quality control sheets of this machine — create a new sheet or open an existing one.",
  "Fiches de contrôle qualité de cette machine.": "Quality control sheets of this machine.",
  "Fiches qualité": "Quality sheets",
  "Dernière fiche": "Latest sheet",
  "Dernier résultat": "Latest result",
  "Dernier contrôle qualité": "Latest quality control",
  "Contrôles qualité de cette machine": "Quality controls of this machine",
  "Référence": "Reference",
  "Date / Heure": "Date / Time",
  "Poste · prélèvements": "Shift · samples",
  "Contrôleur qualité": "Quality Inspector",
  "Ligne": "Line",
  "Poste": "Shift",
  "Dernier prélèvement": "Last sample",
  "Référence copiée": "Reference copied",
  "Ouvrir le contrôle qualité": "Open the quality control",
  "Copier la référence": "Copy the reference",

  // Historique
  "Historique des contrôles qualité": "Quality control history",
  "Recherchez et filtrez les contrôles qualité PROMESH et PROBAR.": "Search and filter PROMESH and PROBAR quality controls.",
  "Aucun contrôle qualité pour ces critères": "No quality control for these criteria",
  "Aucun contrôle qualité pour le moment": "No quality control yet",
  "Référence, ligne, contrôleur, machine…": "Reference, line, inspector, machine…",

  // Export
  "Exporter": "Export",
  "Export…": "Exporting…",
  "Excel (.xlsx)": "Excel (.xlsx)",
  "PDF (A4)": "PDF (A4)",
  "CSV (;)": "CSV (;)",
  "Exporter la comparaison": "Export the comparison",

  // Comparaison
  "Comparez les performances qualité entre deux périodes.": "Compare quality performance between two periods.",
  "Période A : la date de début doit précéder la date de fin.": "Period A: the start date must be before the end date.",
  "Période B : la date de début doit précéder la date de fin.": "Period B: the start date must be before the end date.",
  "Date début": "Start date",
  "Date fin": "End date",
  "Comptes Contrôle Qualité": "Quality Control accounts",
  "Périodes et filtres": "Periods and filters",
  "Les filtres s'appliquent aux deux périodes": "Filters apply to both periods",
  "Période A": "Period A",
  "Période B": "Period B",
  "Toutes machines": "All machines",
  "Comparer": "Compare",
  "Indicateurs": "Indicators",
  "Indicateur": "Indicator",
  "Évolution": "Change",
  "Taux calculés sur les contrôles qualité validés (brouillons = « À vérifier ») ; évolution des taux en points.":
      "Rates computed on validated quality controls (drafts = “To verify”); rate changes in points.",
  "Résultats : période A vs période B": "Results: period A vs period B",
  "Contrôles qualité validés": "Validated quality controls",
  "Aucun contrôle qualité validé sur ces périodes — taux N/A": "No validated quality control over these periods — rate N/A",
  "Comparaison par machine": "Comparison by machine",
  "Aucune machine pour ces filtres": "No machine for these filters",
  "Taux A": "Rate A",
  "Taux B": "Rate B",
  "Taux conformité": "Compliance rate",
  "Taux de conformité": "Compliance rate",
  "Taux de non-conformité": "Non-compliance rate",
  "Moy. paramètres NC / contrôle": "Avg. NC parameters / control",
  "Paramètres contrôlés": "Checked parameters",
  "Paramètres non conformes": "Non-compliant parameters",
  "Aucune ligne pour ces filtres": "No line for these filters",
  "Paramètres qualité": "Quality parameters",
  "Non-conformités par paramètre et par période": "Non-compliances by parameter and period",
  "Aucun paramètre non conforme sur ces périodes": "No non-compliant parameter over these periods",
  "Paramètre": "Parameter",
  "Top paramètres non conformes": "Top non-compliant parameters",
  "Périodes A + B": "Periods A + B",
  "Aucune non-conformité": "No non-compliance",
  // Dashboard Production (mêmes composants que le Contrôle Qualité)
  "Dashboard Production": "Production Dashboard",
  "Suivez les productions PROMESH et PROBAR, les quantités, les déchets, les fiches et les performances.": "Track PROMESH and PROBAR production, quantities, waste, sheets and performance.",
  "Actualiser": "Refresh",
  "Les indicateurs, les graphiques et les listes se recalculent sur la période choisie": "Indicators, charts and lists are recomputed for the selected period",
  "Personnalisée": "Custom",
  "Choisissez une date de début et une date de fin.": "Choose a start date and an end date.",
  "Périmètre : vos propres fiches de production.": "Scope: your own production sheets.",
  "La date de début doit précéder la date de fin.": "The start date must be before the end date.",
  "Productions validées": "Validated productions",
  "Quantité produite": "Quantity produced",
  "Déchets": "Waste",
  "Taux de déchets": "Waste rate",
  "Au moins une fiche sur la période": "At least one sheet over the period",
  "Productions aujourd'hui": "Productions today",
  "Fiches du jour, toutes lignes": "Today's sheets, all lines",
  "Calculés sur les fiches enregistrées · quantités : fiches validées": "Computed from recorded sheets · quantities: validated sheets",
  "Production par machine": "Production by machine",
  "Résumé": "Summary",
  "Fiches": "Sheets",
  "Quantité": "Quantity",
  "Aucune production": "No production",
  "Aucune fiche sur la période": "No sheet over the period",
  "Production par jour": "Production by day",
  "Quantité des fiches validées, par date de production · une échelle par ligne (m² et m ne sont pas comparables)": "Quantity of validated sheets, by production date · one scale per line (m² and m are not comparable)",
  "Aucune production validée sur cette période": "No validated production over this period",
  "Production PROMESH vs PROBAR": "PROMESH vs PROBAR production",
  "Nombre de fiches par statut": "Number of sheets by status",
  "Validées": "Validated",
  "Brouillons": "Drafts",
  "Archivées": "Archived",
  "Aucune fiche sur cette période": "No sheet over this period",
  "Évolution des déchets": "Waste trend",
  "Déchets déclarés par jour (kg)": "Waste declared per day (kg)",
  "Aucun déchet déclaré sur cette période": "No waste declared over this period",
  "Dernières productions": "Latest productions",
  "Les fiches les plus récentes de la période, toutes lignes": "The most recent sheets of the period, all lines",
  "Toutes les fiches": "All sheets",
  "Aucune production sur cette période": "No production over this period",
  "Date": "Date",
  "Utilisateur": "User",
  "Action": "Action",
  "Validée": "Validated",
  "Archivée": "Archived",
  "Accès rapides": "Quick access",
  "Nouvelle fiche PROMESH": "New PROMESH sheet",
  "Nouvelle fiche PROBAR": "New PROBAR sheet",
  "Choisir la machine et le poste": "Choose the machine and the shift",
  "Résumé PROMESH": "PROMESH summary",
  "Résumé PROBAR": "PROBAR summary",
  "Production Summary et export": "Production Summary and export",
  "Fiches de production": "Production sheets",
  "Historique PROMESH et PROBAR, filtres": "PROMESH and PROBAR history, filters",
  "Résumé Production": "Production summary",
  "Toutes lignes, par diamètre": "All lines, by diameter",
  // Comparaison dynamique (KPI, classement, paramètres, analyse)
  "Analysez l'évolution de la qualité entre deux périodes.": "Analyse how quality changes between two periods.",
  "Semaine précédente": "Previous week",
  "Mois précédent": "Previous month",
  "Ce trimestre": "This quarter",
  "Trimestre précédent": "Previous quarter",
  "Année précédente": "Previous year",
  "Personnalisé": "Custom",
  "Tous les postes": "All shifts",
  "Tous les contrôleurs": "All inspectors",
  "Tous les résultats": "All results",
  "À vérifier (brouillon)": "To verify (draft)",
  "Variation": "Change",
  "Variation non calculée": "Change not computed",
  "Évolution du taux de conformité": "Compliance rate trend",
  "Par jour de la période (J1 = premier jour) · contrôles qualité validés": "By day of the period (J1 = first day) · validated quality controls",
  "Indicateurs communs aux deux lignes": "Indicators common to both lines",
  "Les paramètres propres à une ligne (treillis GFRP, barre…) ne sont jamais comparés entre PROMESH et PROBAR.": "Line-specific parameters (GFRP mesh, bar…) are never compared between PROMESH and PROBAR.",
  "Meilleure performance": "Best performance",
  "Performance à surveiller": "Performance to watch",
  "Classement des machines": "Machine ranking",
  "Évolution de la machine": "Machine trend",
  "Taux de conformité sur la période B (contrôles qualité validés)": "Compliance rate over period B (validated quality controls)",
  "Évolution du taux": "Rate change",
  "Classement non établi : moins de deux machines ont des contrôles qualité validés sur la période B.": "No ranking: fewer than two machines have validated quality controls over period B.",
  "Données limitées": "Limited data",
  "Évolution des paramètres": "Parameter trends",
  "Taux de conformité des paramètres contrôlés sur ces périodes": "Compliance rate of the parameters checked over these periods",
  "Aucun paramètre contrôlé sur ces périodes": "No parameter checked over these periods",
  "Améliorations": "Improvements",
  "Points d'attention": "Points of attention",
  "Paramètres dont la conformité augmente": "Parameters whose compliance is rising",
  "Paramètres dont la conformité diminue": "Parameters whose compliance is falling",
  "Aucune amélioration détectée sur ces données": "No improvement detected in this data",
  "Aucun point d'attention détecté sur ces données": "No point of attention detected in this data",
  "Matin / Soir": "Morning / Evening",
  "Comparaison par poste": "Comparison by shift",
  "Aucun écart calculable entre les postes sur la période B : moins de deux contrôles qualité validés par poste, ou écart inférieur à 1 point.": "No computable gap between shifts over period B: fewer than two validated quality controls per shift, or a gap under 1 point.",
  "Analyse": "Analysis",
  "Synthèse calculée à partir des données sélectionnées": "Summary computed from the selected data",
  "Pas suffisamment de données pour cette analyse": "Not enough data for this analysis",
  "Machines contrôlées": "Machines checked",
  "Moy. paramètres contrôlés / contrôle": "Avg. checked parameters / control",
  "Moy. non-conformités / contrôle": "Avg. non-compliances / control",
  "Aucune donnée disponible pour la période A": "No data available for period A",
  "Aucune donnée disponible pour la période B": "No data available for period B",
  "Comparaison impossible : données insuffisantes": "Comparison not possible: insufficient data",
  "Pas suffisamment de données pour cette analyse : aucun contrôle qualité sur les deux périodes.": "Not enough data for this analysis: no quality control over either period.",
  "Taux de conformité non calculable : aucune fiche validée sur au moins une des périodes.": "Compliance rate cannot be computed: no validated sheet over at least one of the periods.",
  "A et B": "A and B",

  // Fiche — identification
  "Identification": "Identification",
  "Ligne, machine et contrôleur fixés par la page · date, poste et ouverture modifiables · lot et fabrication repris automatiquement de la production":
      "Line, machine and inspector set by the page · date, shift and opening editable · lot and manufacturing taken automatically from production",
  "Ligne · Machine": "Line · Machine",
  "Date de production": "Production date",
  "Lot de fabrication": "Manufacturing lot",
  "Ordre de fabrication": "Manufacturing order",
  "Ouvert le": "Opened on",
  "Heure d'ouverture": "Opening time",
  "Date d'ouverture": "Opening date",
  "Date (JJ/MM/AAAA)": "Date (DD/MM/YYYY)",
  "À renseigner": "To fill in",
  "Date à renseigner": "Date to fill in",
  "Sélectionner": "Select",
  "Non renseigné": "Not provided",
  "Non renseigné — saisie manuelle": "Not provided — manual entry",
  "Repris automatiquement de la fiche de production": "Taken automatically from the production sheet",
  "Automatique": "Automatic",
  "Machine —": "Machine —",
  "Aucune fiche de production correspondante trouvée. Le contrôle qualité peut néanmoins être enregistré.":
      "No matching production sheet found. The quality control can still be saved.",
  "Plusieurs fiches de production correspondent à cette date et ce poste : aucune association automatique. Le contrôle qualité peut néanmoins être enregistré.":
      "Several production sheets match this date and shift: no automatic link. The quality control can still be saved.",
  "Date d'ouverture : date valide obligatoire.": "Opening date: a valid date is required.",
  "Heure d'ouverture : heure valide obligatoire.": "Opening time: a valid time is required.",
  "Date de production : date valide obligatoire.": "Production date: a valid date is required.",
  "Heure du prélèvement : heure valide obligatoire.": "Sample time: a valid time is required.",

  // Fiche — prélèvements
  "Prélèvements de contrôle": "Control Samples",
  "Étape 1 en cours de saisie — enregistrez-la pour ajouter le prélèvement suivant": "Step 1 being entered — save it to add the next sample",
  "après l'étape 1": "after step 1",
  "Nouveau prélèvement": "New sample",
  "Non enregistré": "Not saved",
  "Aucun prélèvement.": "No sample.",
  "Suivante": "Next",
  "Précédente": "Previous",
  "Étape 1 — non enregistrée": "Step 1 — not saved",
  "Prélèvement brouillon — modifiable": "Draft sample — editable",
  "Heure du prélèvement": "Sample time",
  "Supprimer le prélèvement": "Delete the sample",
  "Enregistrer le prélèvement": "Save Sample",
  "Valider le prélèvement": "Validate Sample",
  "Résultat du prélèvement": "Sample result",
  "À vérifier — non validé": "To verify — not validated",
  "Un paramètre non conforme impose le résultat NON CONFORME.": "A non-compliant parameter forces the NON-COMPLIANT result.",
  "Valeur": "Value",
  "Remarque": "Remark",
  "Expliquer l'anomalie (recommandé)": "Explain the anomaly (recommended)",
  "Ajouter une remarque": "Add a remark",
  "Reprendre": "Reuse",
  "Valeur obligatoire": "Value required",
  "Indiquer Conforme ou Non conforme": "Select Compliant or Non-compliant",
  "Au moins un paramètre doit être contrôlé (Conforme ou Non conforme).": "At least one parameter must be checked (Compliant or Non-compliant).",
  "Au moins un paramètre doit être contrôlé (Conforme ou Non conforme)": "At least one parameter must be checked (Compliant or Non-compliant)",
  "Au moins un prélèvement de contrôle est obligatoire": "At least one control sample is required",
  "Champs obligatoires manquants": "Required fields missing",
  "Prélèvement déjà enregistré": "Sample already saved",
  "Choisir une autre heure": "Choose another time",
  "Ouvrir le prélèvement existant": "Open the existing sample",
  "Fiche déjà ouverte": "Sheet already open",
  "Ouvrir la fiche existante": "Open the existing sheet",
  "Le prélèvement ne sera plus modifiable. La fiche reste ouverte : vous pourrez ajouter les prélèvements suivants.":
      "The sample will no longer be editable. The sheet stays open: you can add the next samples.",

  // Fiche — paramètres physiques, treillis, synthèse
  "Indépendants du temps : saisis une seule fois pour la fiche, communs à tous les prélèvements": "Time-independent: entered once for the sheet, shared by all samples",
  "Aucun paramètre physique défini pour cette ligne.": "No physical parameter defined for this line.",
  "Paramètres de la fiche déjà enregistrés.": "Sheet parameters already saved.",
  "Paramètres de la fiche enregistrés.": "Sheet parameters saved.",
  "Contrôle spécifique des treillis GFRP": "Specific GFRP Mesh Control",
  "Caractéristiques du treillis": "Mesh characteristics",
  "Résultat du contrôle dimensionnel": "Dimensional control result",
  "ex. 20 × 20 mm": "e.g. 20 × 20 mm",
  "Contrôle dimensionnel et géométrique": "Dimensional and geometric control",
  "Contrôle dimensionnel et géométrique du treillis GFRP — indépendant des prélèvements, saisi une seule fois pour la fiche":
      "Dimensional and geometric control of the GFRP mesh — independent of the samples, entered once for the sheet",
  "Contrôle dimensionnel, assemblage et mécanique · indépendant des prélèvements, saisi une seule fois pour la fiche":
      "Dimensional, assembly and mechanical control · independent of samples, entered once for the sheet",
  "Synthèse": "Summary",
  "Tous les prélèvements enregistrés de la fiche · « Valider le prélèvement » fige l'étape affichée, « Valider le contrôle qualité » clôture la fiche":
      "All saved samples of the sheet · “Validate Sample” locks the displayed step, “Validate Quality Control” closes the sheet",
  "Fiche QC": "QC sheet",
  "non enregistrée": "not saved",
  "Non-conformités": "Non-compliances",
  "Prélèvements conformes": "Compliant samples",
  "Prélèvements non conformes": "Non-compliant samples",
  "Prélèvements à vérifier (brouillons)": "Samples to verify (drafts)",
  "Résultat global": "Overall result",
  "Remarque générale sur la fiche (facultative)": "General remark on the sheet (optional)",
  "Contrôle qualité validé — Lecture seule": "Quality control validated — Read only",
  "Valider le contrôle qualité": "Validate Quality Control",
  "Contrôle qualité enregistré avec succès.": "Quality control saved successfully.",
  "Supprimer le brouillon": "Delete the draft",
  "Brouillon supprimé.": "Draft deleted.",
  "Erreur serveur": "Server error",
  "Erreur réseau": "Network error",
  "Un contrôle validé est en lecture seule et ne peut plus être modifié.": "A validated control is read only and can no longer be edited.",
  "Un contrôle validé ne peut pas être supprimé.": "A validated control cannot be deleted.",
  "Un prélèvement validé est en lecture seule et ne peut plus être modifié.": "A validated sample is read only and can no longer be edited.",
  "Un prélèvement validé ne peut pas être supprimé.": "A validated sample cannot be deleted.",
  "Tous les prélèvements de cette fiche sont validés : créez un nouveau prélèvement.": "All samples of this sheet are validated: create a new sample.",

  // Catégories (backend)
  "Paramètres de ligne": "Line Parameters",
  "Contrôle qualité de la machine": "Machine Quality Control",
  "Contrôle des paramètres de fonctionnement et de réglage de la machine": "Control of the machine operating and setting parameters",
  "PARAMÈTRES DE LIGNE": "LINE PARAMETERS",
  "CHAUFFAGE / IMPRÉGNATION": "HEATING / IMPREGNATION",
  "MACHINE": "MACHINE",
  "Paramètres du prélèvement": "Sample parameters",
  "DIAMÈTRE DE BAR": "BAR DIAMETER",
  "NOMBRE DE BAR EN LONGUEUR": "NUMBER OF BARS LENGTHWISE",
  "NOMBRE DE BAR EN LARGEUR": "NUMBER OF BARS WIDTHWISE",
  "DIMENSIONS CÔTÉ 1 LONG": "LONG SIDE 1 DIMENSIONS",
  "ÉTAT DISQUE DE COUPE": "CUTTING DISC CONDITION",
  "Chauffage / imprégnation": "Heating / Impregnation",
  "Polymérisation": "Polymerisation",
  "Barre": "Bar",
  "Refroidissement / coupe": "Cooling / cutting",
  "Paramètres physiques": "Physical Parameters",
  "Géométrie": "Geometry",
  "Assemblage": "Assembly",
  "Mécanique": "Mechanical",

  // Paramètres des prélèvements (backend)
  "NIVEAU BAIN DE GRAINES": "SEED BATH LEVEL",
  "VITESSE DE TIRAGE": "PULLING SPEED",
  // PROBAR — paramètres de ligne propres aux barres
  "VARIATEUR EN FRÉQUENCE DE TIRAGE": "PULLING FREQUENCY DRIVE",
  "VARIATEUR EN FRÉQUENCE DE BOBINAGE": "WINDING FREQUENCY DRIVE",
  "VITESSE DE BARRE (m/min)": "BAR SPEED (m/min)",
  "TEMPÉRATURE ZONE 1": "ZONE 1 TEMPERATURE",
  "TEMPÉRATURE ZONE 2": "ZONE 2 TEMPERATURE",
  "TEMPÉRATURE ZONE 3": "ZONE 3 TEMPERATURE",
  "PRESSION D'AIR": "AIR PRESSURE",
  "VITESSE DE TIRAGE DE BOBINAGE": "WINDING PULLING SPEED",
  "NOMBRE DE BOBINES": "NUMBER OF SPOOLS",
  "VITESSE DE BOBINAGE (m/min)": "WINDING SPEED (m/min)",
  "VITESSE D'ALIMENTATION DES FIBRES": "FIBRE FEED SPEED",
  "TENSION DES ROVINGS": "ROVING TENSION",
  "NOMBRE DE ROVINGS": "NUMBER OF ROVINGS",
  "ALIGNEMENT DES FIBRES": "FIBRE ALIGNMENT",
  "TEMPÉRATURE DES DIFFÉRENTES ZONES DE CHAUFFAGE": "TEMPERATURE OF THE HEATING ZONES",
  "TEMPÉRATURE DE LA FILIÈRE": "DIE TEMPERATURE",
  "PRESSION / CONDITIONS D'IMPRÉGNATION": "IMPREGNATION PRESSURE / CONDITIONS",
  "VISCOSITÉ DE LA RÉSINE": "RESIN VISCOSITY",
  "RATIO RÉSINE / DURCISSEUR / CATALYSEUR": "RESIN / HARDENER / CATALYST RATIO",
  "TEMPS DE GEL": "GEL TIME",
  "DEGRÉ DE POLYMÉRISATION": "DEGREE OF POLYMERISATION",
  "VITESSE DE POLYMÉRISATION": "POLYMERISATION SPEED",
  "DIAMÈTRE DE LA BARRE": "BAR DIAMETER",
  "OVALISATION": "OVALITY",
  "ÉTAT DE SURFACE": "SURFACE CONDITION",
  "QUANTITÉ ET RÉGULARITÉ DU REVÊTEMENT": "COATING QUANTITY AND REGULARITY",
  "VITESSE DE REFROIDISSEMENT": "COOLING SPEED",
  "VITESSE DE COUPE": "CUTTING SPEED",
  "LONGUEUR DE COUPE": "CUTTING LENGTH",
  "TEMPÉRATURE DE MACHINE": "MACHINE TEMPERATURE",
  "TEMPÉRATURE D'EAU": "WATER TEMPERATURE",
  "PRESSION D'AIR COMPRIMÉ": "COMPRESSED AIR PRESSURE",
  "ÉTAT D'IMPRESSION": "PRINT CONDITION",
  "FUITE D'AIR COMPRIMÉ": "COMPRESSED AIR LEAK",
  "FUITE D'EAU": "WATER LEAK",
  "ÉTAT DU DISQUE DE COUPE": "CUTTING DISC CONDITION",
  // Choix des paramètres
  "Bien": "Good",
  "Moyen": "Average",
  "Mauvais": "Poor",
  "Absent": "Absent",
  "Présent": "Present",
  "OK": "OK",
  "NOK": "NOK",
  "ex. 20 x 20": "e.g. 20 x 20",
  // Paramètres physiques PROMESH
  "NOMBRE DE BARRES EN LONGUEUR": "NUMBER OF BARS LENGTHWISE",
  "NOMBRE DE BARRES EN LARGEUR": "NUMBER OF BARS WIDTHWISE",
  "DIMENSIONS DE MAILLE": "MESH DIMENSIONS",
  "DIMENSIONS CÔTÉ 1": "DIMENSIONS SIDE 1 LENGTH",
  "DIMENSIONS CÔTÉ 2": "DIMENSIONS SIDE 2 LENGTH",
  // Paramètres physiques PROBAR
  "DIAMÈTRE NOMINAL": "NOMINAL DIAMETER",
  "DIAMÈTRE RÉEL": "ACTUAL DIAMETER",
  "SECTION TRANSVERSALE": "CROSS-SECTION",
  "LONGUEUR": "LENGTH",
  "MASSE LINÉIQUE": "LINEAR MASS",
  "POIDS EN g": "WEIGHT IN g",
  "Contrôle produit": "Product Control",
  "Au moins un paramètre doit être renseigné.": "At least one parameter must be filled in.",
  "TEMPÉRATURE MACHINE 1 — ZONE 1": "MACHINE TEMPERATURE 1 — ZONE 1",
  "TEMPÉRATURE MACHINE 1 — ZONE 2": "MACHINE TEMPERATURE 1 — ZONE 2",
  "TEMPÉRATURE MACHINE 2 — ZONE 1": "MACHINE TEMPERATURE 2 — ZONE 1",
  "TEMPÉRATURE MACHINE 2 — ZONE 2": "MACHINE TEMPERATURE 2 — ZONE 2",
  "ZONE 1": "ZONE 1",
  "ZONE 2": "ZONE 2",
  "DIMENSIONS CÔTÉ 1 LONGUEUR": "SIDE 1 LENGTH DIMENSIONS",
  "DIMENSIONS CÔTÉ 2 LONGUEUR": "SIDE 2 LENGTH DIMENSIONS",
  "Contrôle PROMESH 4": "PROMESH 4 Control",
  "Paramètres spécifiques de la machine": "Machine-specific parameters",
  "TEMPÉRATURE MACHINE 1": "MACHINE TEMPERATURE 1",
  "TEMPÉRATURE MACHINE 2": "MACHINE TEMPERATURE 2",
  "VISCOSITÉ DE LA RÉSINE — BAIN 1": "RESIN VISCOSITY — BATH 1",
  "VISCOSITÉ DE LA RÉSINE — BAIN 2": "RESIN VISCOSITY — BATH 2",
  "BAIN 1": "BATH 1",
  "BAIN 2": "BATH 2",
  "Contrôle Machine": "Machine Control",
  "Contrôle Produit": "Product Control",
  "Paramètres liés au prélèvement": "Parameters linked to the sample",
  "Caractéristiques du produit — saisies une seule fois pour la fiche, communes à tous les prélèvements": "Product characteristics — entered once for the sheet, shared by all samples",
  "DIMENSIONS CÔTÉ 2 LONG": "SIDE 2 LENGTH DIMENSIONS",
  "VITESSE D'IMPRESSION": "PRINTING SPEED",
  "Contrôle dimensionnel et qualité du produit — indépendant des prélèvements": "Dimensional and product quality control — independent of the samples",
  "RECTITUDE": "STRAIGHTNESS",
  "PAS DU PROFIL DE SURFACE": "SURFACE PROFILE PITCH",
  "HAUTEUR / PROFONDEUR DES NERVURES OU ENROULEMENT": "HEIGHT / DEPTH OF RIBS OR WINDING",
  "RÉGULARITÉ DU REVÊTEMENT": "COATING REGULARITY",
  "DÉFAUTS SUPERFICIELS": "SURFACE DEFECTS",
  "CEINTURE DE TIRAGE": "PULLING BELT",
  "QUALITÉ DE COUPE": "CUT QUALITY",
  "Bon": "Good",
  "Pas bon": "Not good",
  // Treillis GFRP
  "LARGEUR": "WIDTH",
  "MAILLE LONGITUDINALE": "LONGITUDINAL MESH",
  "MAILLE TRANSVERSALE": "TRANSVERSE MESH",
  "DIAMÈTRE / SECTION DES ÉLÉMENTS": "DIAMETER / SECTION OF THE ELEMENTS",
  "TOLÉRANCE DIMENSIONNELLE": "DIMENSIONAL TOLERANCE",
  "ESPACEMENT DES FILS": "WIRE SPACING",
  "POIDS PAR M²": "WEIGHT PER M²",
  "RECTITUDE / PLANÉITÉ": "STRAIGHTNESS / FLATNESS",
  "QUALITÉ DES INTERSECTIONS": "QUALITY OF THE INTERSECTIONS",
  "POSITIONNEMENT DES FILS": "WIRE POSITIONING",
  "CONTINUITÉ DES ÉLÉMENTS": "CONTINUITY OF THE ELEMENTS",
  "QUALITÉ DU POINT DE LIAISON": "QUALITY OF THE BONDING POINT",
  "RÉSISTANCE DE L'INTERSECTION": "INTERSECTION STRENGTH",
  "ABSENCE DE DÉLAMINATION / DÉFAUT": "NO DELAMINATION / DEFECT",
  "RÉSISTANCE EN TRACTION LONGITUDINALE": "LONGITUDINAL TENSILE STRENGTH",
  "RÉSISTANCE EN TRACTION TRANSVERSALE": "TRANSVERSE TENSILE STRENGTH",
  "MODULE": "MODULUS",
  "DÉFORMATION": "STRAIN",
  "RÉSISTANCE DE L'INTERSECTION / LIAISON": "INTERSECTION / BOND STRENGTH",
};

final List<_Template> _templates = [
  // Fiche — titres et identification
  _tpl("Contrôle qualité indisponible : {}", "Quality control unavailable: {0}"),
  _tpl("Nouveau contrôle qualité {}", "New Quality Control {0}"),
  _tpl("Poste : {}", "Shift: {0}"),
  _tpl("Poste {}", "Shift {0}"),
  _tpl("Lot : {}", "Lot: {0}"),
  _tpl("Fabrication : non renseignée", "Manufacturing: not provided"),
  _tpl("Fabrication : {}", "Manufacturing: {0}"),
  _tpl("Valeur existante : {} — choisir Matin ou Soir", "Existing value: {0} — choose Morning or Evening"),
  _tpl(
    "Contrôle qualité validé — Lecture seule · validé le {} à {} par {}. Aucune modification ni suppression possible.",
    "Quality control validated — Read only · validated on {0} at {1} by {2}. No edit or deletion possible.",
  ),
  _tpl("Fiche validée le {} à {} par {}", "Sheet validated on {0} at {1} by {2}"),

  // Prélèvements
  _tpl("Prélèvements : {} — Non conformes : {}", "Samples: {0} — Non-compliant: {1}"),
  _tpl("{} · {} prélèvements ({})", "{0} · {1} samples ({2})"),
  _tpl("{} · {} prélèvement ({})", "{0} · {1} sample ({2})"),
  _tpl("{} · {} prélèvements", "{0} · {1} samples"),
  _tpl("{} · {} prélèvement", "{0} · {1} sample"),
  _tpl("Prélèvements : {}", "Samples: {0}"),
  _tpl("Non conformes : {}", "Non-compliant: {0}"),
  _tpl("{} prélèvements", "{0} samples"),
  _tpl("{} prélèvement", "{0} sample"),
  _tpl("{} étapes · cliquer sur une étape affiche son prélèvement ci-dessous · chaque prélèvement conserve ses propres valeurs",
      "{0} steps · click a step to display its sample below · each sample keeps its own values"),
  _tpl("{} étape · cliquer sur une étape affiche son prélèvement ci-dessous · chaque prélèvement conserve ses propres valeurs",
      "{0} step · click a step to display its sample below · each sample keeps its own values"),
  _tpl("proposé : {}", "suggested: {0}"),
  _tpl("ÉTAPE {}", "STEP {0}"),
  _tpl("Étape {} / {}", "Step {0} / {1}"),
  _tpl("Étape {} créée — prélèvement de {}.", "Step {0} created — sample of {1}."),
  _tpl("Prélèvement actuel — étape {}", "Current Sample — step {0}"),
  _tpl("Prélèvement validé le {} à {} — lecture seule", "Sample validated on {0} at {1} — read only"),
  _tpl("Prélèvement de {} validé — lecture seule", "Sample of {0} validated — read only"),
  _tpl("Prélèvement de {} supprimé.", "Sample of {0} deleted."),
  _tpl("Prélèvement de {} · {} / {} paramètres contrôlés · {} non conforme(s)", "Sample of {0} · {1} / {2} parameters checked · {3} non-compliant"),
  _tpl("Prélèvement de {}", "Sample of {0}"),
  _tpl("CONTRÔLES DU PRÉLÈVEMENT {} — {}", "CHECKS OF SAMPLE {0} — {1}"),
  _tpl("{}/{} contrôlés", "{0}/{1} checked"),
  _tpl("{} non conformes", "{0} non-compliant"),
  _tpl("{} non conforme", "{0} non-compliant"),
  _tpl("{} / {} contrôlé(s)", "{0} / {1} checked"),
  _tpl("{} / {} renseigné(s)", "{0} / {1} filled in"),
  _tpl("  ·  {} NC", "  ·  {0} NC"),
  _tpl("  · {} NC", "  · {0} NC"),
  _tpl("{} NC", "{0} NC"),
  _tpl("Précédent ({}) : {}", "Previous ({0}): {1}"),
  _tpl("Paramètre(s) non conforme(s) : {}", "Non-compliant parameter(s): {0}"),
  _tpl("Paramètres physiques {}", "Physical Parameters {0}"),
  _tpl("Paramètres spécifiques {}", "{0} Specific Parameters"),
  _tpl("dernier : {}", "last: {0}"),
  _tpl("Un prélèvement existe déjà pour {}.", "A sample already exists for {0}."),
  _tpl("Valider le prélèvement de {}", "Validate the sample of {0}"),
  _tpl(
    "Résultat : {}\n\nLe prélèvement ne sera plus modifiable. La fiche reste ouverte : vous pourrez ajouter les prélèvements suivants.",
    "Result: {0}\n\nThe sample will no longer be editable. The sheet stays open: you can add the next samples.",
  ),
  _tpl(
    "Résultat : {} · {} prélèvement(s)\n\nOuvert le {} à {}. La fiche et tous ses prélèvements passent en lecture seule : aucun prélèvement ne pourra plus être ajouté. "
        "L'horodatage de la validation et le contrôleur sont enregistrés automatiquement.",
    "Result: {0} · {1} sample(s)\n\nOpened on {2} at {3}. The sheet and all its samples become read only: no sample can be added any more. "
        "The validation timestamp and the inspector are recorded automatically.",
  ),
  _tpl("Prélèvement validé : {} — {} responsable(s) notifié(s)", "Sample validated: {0} — {1} manager(s) notified"),
  _tpl("Prélèvement validé : {}", "Sample validated: {0}"),
  _tpl("Contrôle qualité validé : {} — {} responsable(s) notifié(s)", "Quality control validated: {0} — {1} manager(s) notified"),
  _tpl("Contrôle qualité validé : {}", "Quality control validated: {0}"),
  _tpl("La fiche qualité {} (brouillon) de la {} et ses {} prélèvement(s) seront supprimés.", "Quality sheet {0} (draft) of {1} and its {2} sample(s) will be deleted."),
  _tpl("L'étape {} — prélèvement de {} (brouillon) — sera supprimée. Les autres prélèvements de la fiche sont conservés.",
      "Step {0} — sample of {1} (draft) — will be deleted. The other samples of the sheet are kept."),
  _tpl("{} : Valeur obligatoire", "{0}: Value required"),
  _tpl("{} : Indiquer Conforme ou Non conforme", "{0}: Select Compliant or Non-compliant"),
  // Messages du backend
  _tpl("Prélèvement {} — {}", "Sample {0} — {1}"),
  _tpl("{} : valeur obligatoire pour un paramètre contrôlé", "{0}: a value is required for a checked parameter"),
  _tpl("{} : indiquer Conforme ou Non conforme pour la valeur saisie", "{0}: select Compliant or Non-compliant for the entered value"),
  _tpl("{} : paramètre non applicable à {}", "{0}: parameter not applicable to {1}"),
  _tpl(
    "Une fiche de contrôle qualité est déjà ouverte pour {} · {}, le {}, poste {} ({}). Ouvrez cette fiche pour y ajouter un prélèvement.",
    "A quality control sheet is already open for {0} · {1}, on {2}, shift {3} ({4}). Open that sheet to add a sample.",
  ),

  // Tableau de bord / lignes / machines
  _tpl("Configuration indisponible : {}", "Configuration unavailable: {0}"),
  _tpl("Statistiques indisponibles : {}", "Statistics unavailable: {0}"),
  _tpl("MACHINES {}", "MACHINES {0}"),
  _tpl("Machines {}", "{0} machines"),
  _tpl("{} à vérifier", "{0} to verify"),
  _tpl("{} ctrl", "{0} ctrl"),
  _tpl("Ouvrir Machine {}", "Open Machine {0}"),
  _tpl("Ouvrir la machine", "Open the machine"),
  _tpl("Ouvrir {}", "Open {0}"),
  _tpl("Voir la ligne {}", "View line {0}"),
  _tpl("Voir {}", "View {0}"),
  _tpl("{} % des validés", "{0}% of validated"),
  _tpl("{} C · {} NC · {} à vérifier", "{0} C · {1} NC · {2} to verify"),
  _tpl("{} machines · contrôles qualité : {} · dernier contrôle qualité : toutes périodes", "{0} machines · quality controls: {1} · latest quality control: all periods"),
  _tpl("{} machines", "{0} machines"),
  _tpl("Ligne de production inconnue : {}", "Unknown production line: {0}"),
  _tpl("Derniers contrôles qualité {}", "Latest {0} quality controls"),
  _tpl("Aucun contrôle qualité {} pour le moment", "No {0} quality control yet"),
  _tpl("{} / Machine {}", "{0} / Machine {1}"),
  _tpl("{} fiche(s) qualité · {}", "{0} quality sheet(s) · {1}"),
  _tpl("Aucune fiche qualité pour cette machine · {} — « Nouveau contrôle qualité » pour en créer une",
      "No quality sheet for this machine · {0} — “New Quality Control” to create one"),
  _tpl("Aucune fiche qualité pour cette machine · {}", "No quality sheet for this machine · {0}"),
  _tpl("{} contrôle(s) qualité", "{0} quality control(s)"),
  _tpl("Page {} / {}", "Page {0} / {1}"),
  _tpl("Export généré : {}", "Export generated: {0}"),
  _tpl("Export impossible : {}", "Export failed: {0}"),
  _tpl("Fichier {} invalide reçu ({} octets)", "Invalid {0} file received ({1} bytes)"),
  // Comparaison — phrases d'analyse générées par le backend à partir des données
  _tpl("Treillis GFRP · {}", "GFRP mesh · {0}"),
  _tpl("Données limitées : la période {} ne contient qu'un seul contrôle qualité ; les écarts ne constituent pas une tendance fiable.", "Limited data: period {0} contains a single quality control; the gaps are not a reliable trend."),
  _tpl("Données limitées : la période {} ne contient qu'un seul contrôle qualité", "Limited data: period {0} contains a single quality control"),
  _tpl("Comparaison impossible : données insuffisantes (aucun contrôle qualité sur la période {}).", "Comparison not possible: insufficient data (no quality control over period {0})."),
  _tpl("Le nombre de contrôles qualité est passé de {} à {} ({}).", "The number of quality controls went from {0} to {1} ({2})."),
  _tpl("Le nombre de contrôles qualité est passé de {} à {}.", "The number of quality controls went from {0} to {1}."),
  _tpl("Le nombre de contrôles qualité est identique sur les deux périodes ({}).", "The number of quality controls is the same over both periods ({0})."),
  _tpl("Le taux de conformité est resté stable à {}.", "The compliance rate remained stable at {0}."),
  _tpl("Le taux de conformité est passé de {} à {} entre les deux périodes, soit une amélioration de {}.", "The compliance rate went from {0} to {1} between the two periods, an improvement of {2}."),
  _tpl("Le taux de conformité est passé de {} à {} entre les deux périodes, soit une baisse de {}.", "The compliance rate went from {0} to {1} between the two periods, a drop of {2}."),
  _tpl("La diminution des non-conformités concerne principalement les paramètres « {} » ({}).", "The decrease in non-compliances mainly concerns the “{0}” parameters ({1})."),
  _tpl("L'augmentation des non-conformités concerne principalement les paramètres « {} » ({}).", "The increase in non-compliances mainly concerns the “{0}” parameters ({1})."),
  _tpl("Principale amélioration : {} ({} → {}, {}).", "Main improvement: {0} ({1} → {2}, {3})."),
  _tpl("Principal point d'attention : {} ({} → {}, {}).", "Main point of attention: {0} ({1} → {2}, {3})."),
  _tpl("Meilleure performance sur la période B : {} ({}) ; à surveiller : {} ({}).", "Best performance over period B: {0} ({1}); to watch: {2} ({3})."),
  _tpl("Le poste {} présente un taux de non-conformité supérieur de {} au poste {} sur la période B.", "The {0} shift has a non-compliance rate {1} higher than the {2} shift over period B."),
  _tpl("{} points", "{0} points"),
  _tpl("{} point", "{0} point"),
  // Dashboard Production
  _tpl("Fiches {}", "{0} sheets"),
  _tpl("{} brouillon(s) · {} archivée(s)", "{0} draft(s) · {1} archived"),
  _tpl("{} · fiches validées", "{0} · validated sheets"),
  _tpl("{} fiche(s)", "{0} sheet(s)"),
  // Comparaison
  _tpl("Contrôleur qualité : {}", "Quality Inspector: {0}"),
  _tpl("A : {}   ·   B : {}", "A: {0}   ·   B: {1}"),
  _tpl("Période A : {}   ·   Période B : {}   ·   {}", "Period A: {0}   ·   Period B: {1}   ·   {2}"),
  _tpl("Période A — {}", "Period A — {0}"),
  _tpl("Période B — {}", "Period B — {0}"),
  _tpl("Contrôle qualité {}", "Quality control {0}"),
  _tpl("Machine {}", "Machine {0}"),
];
