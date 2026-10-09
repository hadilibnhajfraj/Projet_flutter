// lib/production_records/view/production_summary_screen.dart
//
// "Production Summary / Total Production" — récapitulatif PROBAR/PROMESH
// groupé automatiquement par Diamètre (+ Taille de maille pour PROMESH),
// avec sous-totaux par diamètre et un total (par section) très visible.
// Mirrors GET /production-records/summary (backend :
// modules/production-records/services/productionRecords.service.js#getProductionSummary).
//
// Aucune nouvelle donnée : agrégation en lecture seule des fiches PorPromesh
// et IndustrialRecord (module='probar') existantes, calculée côté SQL.
//
// RÈGLE ABSOLUE : les mètres PROBAR et les m² PROMESH ne sont JAMAIS
// additionnés entre eux, ni affichés dans un même KPI/total — PROMESH et
// PROBAR ont chacun leurs propres cartes KPI, leur propre section et leur
// propre tableau (voir _buildKpiRow / _ProductionSection).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/forms/por_promesh/view/widgets/shimmer_box.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../model/production_record_model.dart';
import '../model/production_summary_model.dart';
import '../service/production_records_service.dart';
import '../service/production_summary_export_service.dart';
import 'production_summary_table_card.dart';

// Grille responsive équi-hauteur/équi-largeur, sans GridView ni ratio fixe —
// voir le commentaire sur _buildKpiRow pour la raison (évite tout risque de
// débordement/chevauchement quand le contenu d'une carte est plus grand que
// prévu). `IntrinsicHeight` + `CrossAxisAlignment.stretch` mesure la ligne
// à la hauteur de sa carte la plus grande et applique cette hauteur à
// toutes les cartes de la ligne ; `Expanded` garantit des largeurs égales.
Widget _responsiveCardGrid(List<Widget> cards, int columns, {double gap = 14}) {
  final rows = <Widget>[];
  for (int i = 0; i < cards.length; i += columns) {
    final rowItems = cards.skip(i).take(columns).toList();
    final rowChildren = <Widget>[];
    for (int j = 0; j < columns; j++) {
      if (j > 0) rowChildren.add(SizedBox(width: gap));
      rowChildren.add(Expanded(child: j < rowItems.length ? rowItems[j] : const SizedBox.shrink()));
    }
    rows.add(IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: rowChildren)));
    if (i + columns < cards.length) rows.add(const SizedBox(height: 14));
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
}

// Le filtre Statut par défaut est "Validées" — mêmes fiches que les autres
// KPI industriels de la page "Fiches de production" (voir
// getProductionTotals) ; "Toutes" est une valeur explicite distincte, jamais
// le comportement implicite en l'absence de filtre (voir
// resolveSummaryStatus côté backend).
const _kStatuses = <(String, String)>[
  ('validee', 'Validée'),
  ('brouillon', 'Brouillon'),
  ('all', 'Toutes'),
];

// §MODIFICATION — DEUX PAGES SÉPARÉES PROMESH/PROBAR (2026-09-08) —
// `fixedType` ('promesh'/'probar') verrouille définitivement le filtre Type
// sur une seule valeur (le sélecteur segmenté "Toutes/PROMESH/PROBAR"
// disparaît, voir `_buildFiltersCard`) : la page ne récupère et n'affiche
// alors QUE ce type, via le MÊME paramètre `type` déjà supporté par
// `fetchSummary`/`GET /production-records/summary` (aucun changement
// backend). `fixedType: null` (défaut) préserve EXACTEMENT le comportement
// combiné historique de l'ancienne route `/production/summary` — jamais
// cassé, pour ne rien casser côté deep-links/favoris existants (voir
// my_route.dart). Aucune duplication de logique : `_ProductionSummaryScreenState`
// reste un SEUL widget partagé, réutilisé par les 3 routes.
class ProductionSummaryScreen extends StatefulWidget {
  final String? fixedType;
  const ProductionSummaryScreen({super.key, this.fixedType});

  @override
  State<ProductionSummaryScreen> createState() => _ProductionSummaryScreenState();
}

class _ProductionSummaryScreenState extends State<ProductionSummaryScreen> {
  bool _loading = true;
  bool _exporting = false;
  String? _error;

  // Initialisé à `widget.fixedType` dans `initState` (jamais modifiable par
  // l'utilisateur quand verrouillé — voir _buildFiltersCard) ; reste
  // librement modifiable via le sélecteur segmenté quand `fixedType` est
  // `null` (page combinée historique, comportement inchangé).
  String? _type; // null = 'Toutes' | 'probar' | 'promesh'
  // §MODIFICATION — PRODUCTION SUMMARY : FILTRE "CUSTOM DATE" UNIQUE +
  // COLONNE SHIFT (2026-09-07) — le filtre de période ne conserve plus QUE
  // "Custom" (§1 du ticket) : `_period` (dropdown "Toutes/Semaine/Mois/
  // Personnalisée") est retiré.
  //
  // §CORRECTION — CUSTOM DATE : SÉLECTION D'UNE SEULE DATE (2026-09-07,
  // ticket suivant) — "Custom Date" filtre sur UN SEUL jour, jamais une
  // plage : `_selectedDate` remplace les anciens `_customStart`/`_customEnd`
  // (DateTimeRange/showDateRangePicker retirés). Envoyé au backend comme
  // `startDate == endDate == _selectedDate` (voir _load ci-dessous) — le
  // backend borne déjà correctement sur le jour calendaire complet
  // [startDate, startDate+1) sans jamais comparer d'heure (computeDateRange,
  // productionRecords.service.js), donc aucun changement backend n'était
  // nécessaire pour ce ticket.
  //
  // §MODIFICATION — CUSTOM DATE : DEUX MODES "DATE UNIQUE" / "PÉRIODE"
  // (2026-09-09) — `_selectedRange` (NOUVEAU) ajoute le mode période à côté
  // du mode date unique déjà existant, SANS le remplacer (§1/§2 du ticket :
  // "permettre deux modes de sélection"). Les deux champs sont mutuellement
  // exclusifs (choisir l'un efface l'autre, voir _customDateChip) — jamais
  // les deux actifs en même temps. `computeDateRange` (backend, DÉJÀ
  // existant, inchangé) borne déjà [startDate, endDate+1) de façon inclusive
  // dès que les deux dates sont fournies (voir Backend Master/src/modules/
  // production-records/utils/dateRange.js) : envoyer directement
  // `_selectedRange.start`/`_selectedRange.end` comme startDate/endDate
  // (voir _load) suffit pour une période inclusive (§6 du ticket), aucun
  // changement backend nécessaire.
  DateTime? _selectedDate;
  DateTimeRange? _selectedRange;
  String? _machineFilter;
  String? _diameterFilter;
  String _status = 'validee';

  // §MODIFICATION — TRI DES TABLEAUX "PROMESH/PROBAR PRODUCTION"
  // (2026-09-11) — état de tri PUREMENT client (§22 du ticket : aucun appel
  // backend), un par type, totalement indépendant (trier PROMESH ne touche
  // jamais l'état de tri PROBAR). Vit ICI (pas dans `_ProductionSummaryTableCardState`)
  // pour que l'export Excel/PDF (§16/§17) puisse refléter le tri
  // actuellement actif — voir _sortedSummaryForExport plus bas.
  ProductionRowSort? _promeshSort;
  ProductionRowSort? _probarSort;

  ProductionSummary _summary = const ProductionSummary();
  ProductionRecordFilters _filters = const ProductionRecordFilters();

  @override
  void initState() {
    super.initState();
    _type = widget.fixedType;
    _loadFilters();
    _load();
  }

  Future<void> _loadFilters() async {
    try {
      // §MODIFICATION — PRODUCTION SUMMARY : PARITÉ RESPONSABLE_LOGISTIQUE_ACHAT
      // / SUPERADMIN (2026-09-02) — `forSummary: true` fait lister TOUTES les
      // machines/diamètres (PROMESH 1/2/4 y compris), quel que soit le rôle,
      // exactement comme superadmin — voir production_records_service.dart.
      final f = await ProductionRecordsService.instance.fetchFilters(forSummary: true);
      if (!mounted) return;
      setState(() => _filters = f);
    } catch (_) {
      // Best-effort — les dropdowns retombent sur "Toutes/Tous" uniquement.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // §MODIFICATION — CUSTOM DATE : DEUX MODES (2026-09-09) — mode "Date
      // unique" : `startDate == endDate == _selectedDate` (inchangé). Mode
      // "Période" (NOUVEAU) : `startDate`/`endDate` reçoivent les deux
      // bornes réelles choisies par l'utilisateur — le backend
      // (computeDateRange, DÉJÀ existant, inchangé) calcule alors
      // [startDate, endDate+1), une plage inclusive des deux bornes (§6 du
      // ticket), sans jamais comparer l'heure (`dateProduction`/`dateFiche`
      // sont DATEONLY côté base). Les deux modes sont mutuellement
      // exclusifs (voir _selectedRange/_selectedDate ci-dessus) ;
      // `period: 'custom'` n'est envoyé QUE si une date/période est
      // choisie — le backend ignore totalement startDate/endDate sinon.
      String? startIso;
      String? endIso;
      if (_selectedDate != null) {
        startIso = DateFormat('yyyy-MM-dd').format(_selectedDate!);
        endIso = startIso;
      } else if (_selectedRange != null) {
        startIso = DateFormat('yyyy-MM-dd').format(_selectedRange!.start);
        endIso = DateFormat('yyyy-MM-dd').format(_selectedRange!.end);
      }
      final summary = await ProductionRecordsService.instance.fetchSummary(
        type: _type,
        period: startIso == null ? null : 'custom',
        startDate: startIso,
        endDate: endIso,
        machineId: _machineFilter,
        diameter: _diameterFilter,
        status: _status,
      );
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // §15 du ticket : titre/sous-titre dépendent de `widget.fixedType` — la
  // page combinée historique (`fixedType == null`) garde ses libellés
  // d'origine, inchangés.
  String get _pageTitleKey => switch (widget.fixedType) {
        'promesh' => 'Production Summary — PROMESH',
        'probar' => 'Production Summary — PROBAR',
        _ => 'Production Summary',
      };

  String get _pageSubtitleKey => switch (widget.fixedType) {
        'promesh' => 'Production overview for PROMESH',
        'probar' => 'Production overview for PROBAR',
        _ => 'Production overview for PROBAR and PROMESH',
      };

  Future<void> _refreshAll() => Future.wait([_loadFilters(), _load()]);

  void _onFilterChanged() => _load();

  void _resetFilters() {
    setState(() {
      // Revient au type verrouillé (page dédiée) ou à "Toutes" (page
      // combinée historique) — jamais un Reset qui ferait apparaître
      // l'autre type sur une page dédiée.
      _type = widget.fixedType;
      _selectedDate = null;
      _selectedRange = null;
      _machineFilter = null;
      _diameterFilter = null;
      _status = 'validee';
      // §18/§19 du ticket "tri" : Reset supprime aussi le tri actif des deux
      // tableaux — retour complet à l'ordre par défaut.
      _promeshSort = null;
      _probarSort = null;
    });
    _load();
  }

  // ── Contexte affiché / exporté (jamais recalculé différemment entre écran
  // et export — le PDF/Excel doit refléter EXACTEMENT ce que l'utilisateur
  // voit) ──────────────────────────────────────────────────────────────────
  String _periodLabel(AppLocalizations t) {
    if (_selectedDate != null) {
      return DateFormat('dd/MM/yyyy').format(_selectedDate!);
    }
    if (_selectedRange != null) {
      return '${DateFormat('dd/MM/yyyy').format(_selectedRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedRange!.end)}';
    }
    return t.translate('Toutes les périodes');
  }

  // §MODIFICATION — CORRECTION GLOBALE DES TRADUCTIONS (2026-09-17, ticket
  // "l'interface mélange parfois l'anglais et le français") — le mot
  // "Machine" était écrit en dur (jamais passé par `t.translate`), donc
  // jamais traduit si la langue changeait cette convention à l'avenir —
  // corrigé pour repasser par le système de localisation existant, comme
  // partout ailleurs dans ce fichier (§2/§3 du ticket : ne jamais laisser un
  // texte contourner `AppLocalizations`, ne jamais créer de système
  // parallèle).
  String? get _machineLabel =>
      _machineFilter == null ? null : '${AppLocalizations.of(context).translate('Machine')} $_machineFilter';

  ProductionSummaryExportContext get _exportContext => ProductionSummaryExportContext(
        periodLabel: _periodLabel(AppLocalizations.of(context)),
        machineLabel: _machineLabel,
        diameterLabel: _diameterFilter,
        statusLabel: AppLocalizations.of(context).translate(
          _kStatuses.firstWhere((s) => s.$1 == _status, orElse: () => ('validee', 'Validée')).$2,
        ),
        // Valeurs brutes des filtres — utilisées uniquement par
        // exportExcel() pour calculer dynamiquement la plage de dates
        // réelle des fiches exportées (voir _resolveExcelPeriodRange).
        // §MODIFICATION — CUSTOM DATE : DEUX MODES (2026-09-09) —
        // `rawStartDate`/`rawEndDate` reçoivent EXACTEMENT les mêmes bornes
        // que `_load()` ci-dessus (date unique OU période réelle), pour que
        // l'export reflète toujours exactement ce que l'écran affiche.
        rawPeriod: (_selectedDate == null && _selectedRange == null) ? null : 'custom',
        rawStartDate: _selectedDate != null
            ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
            : (_selectedRange != null ? DateFormat('yyyy-MM-dd').format(_selectedRange!.start) : null),
        rawEndDate: _selectedDate != null
            ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
            : (_selectedRange != null ? DateFormat('yyyy-MM-dd').format(_selectedRange!.end) : null),
        rawMachineId: _machineFilter,
      );

  // §16/§17 du ticket "tri" : Excel/PDF/Impression doivent respecter le tri
  // actuellement actif dans le tableau détaillé — construit une COPIE de
  // `_summary` dont seul `rows` est réordonné (mêmes `grandTotal`/
  // `grandTotalWaste`/`totalRecords`/`unit`, jamais recalculés). Le
  // récapitulatif Excel n'est PAS affecté : `aggregateByMachine` (appelé côté
  // export) retrie de toute façon intégralement par machine/diamètre/cell
  // size, quel que soit l'ordre d'entrée des lignes (§16 : "ne doit pas être
  // détruit par le tri du tableau détaillé").
  ProductionSummary get _sortedSummaryForExport {
    final promesh = _summary.promesh;
    final probar = _summary.probar;
    return ProductionSummary(
      promesh: promesh == null
          ? null
          : ProductionSummaryTable(
              rows: sortProductionRows(promesh.rows, column: _promeshSort?.column, ascending: _promeshSort?.ascending ?? true),
              grandTotal: promesh.grandTotal,
              unit: promesh.unit,
              totalRecords: promesh.totalRecords,
              grandTotalWaste: promesh.grandTotalWaste,
              wasteUnit: promesh.wasteUnit,
            ),
      probar: probar == null
          ? null
          : ProductionSummaryTable(
              rows: sortProductionRows(probar.rows, column: _probarSort?.column, ascending: _probarSort?.ascending ?? true),
              grandTotal: probar.grandTotal,
              unit: probar.unit,
              totalRecords: probar.totalRecords,
              grandTotalWaste: probar.grandTotalWaste,
              wasteUnit: probar.wasteUnit,
            ),
    );
  }

  Future<void> _runExport(Future<void> Function() action) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${AppLocalizations.of(context).translate('Erreur')} : $e'), backgroundColor: kCrmDanger));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;
    final t = AppLocalizations.of(context);
    final promesh = _summary.promesh;
    final probar = _summary.probar;

    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 1. Titre
              _buildHeader(context, isMobile),
              const SizedBox(height: 20),
              // 2. Filtres (Type + Période + Diamètre + Machine + Statut + Reset)
              _buildFiltersCard(context),
              const SizedBox(height: 22),
              // 3. KPI + tableaux — state machine loading/success/empty/error
              // (§7 : une erreur réseau/API ne doit JAMAIS afficher "Number
              // of records = 0" comme si la base était vide — le KPI row
              // n'est donc rendu QUE hors erreur, jamais en même temps que
              // le message d'erreur).
              if (_error != null)
                _buildError(context)
              else ...[
                // §MODIFICATION — SUPPRESSION CARTES KPI SUR LES PAGES DÉDIÉES
                // (2026-09-09, §1/§14/§15 du ticket) — "Total PROMESH/PROBAR"
                // et "Number of records" ne sont plus affichées QUE sur les
                // deux pages dédiées PROMESH/PROBAR (`widget.fixedType !=
                // null`) : le tableau détaillé remonte alors naturellement à
                // leur place (§19, aucun espace vide laissé — voir aussi le
                // SizedBox(height: 26) ci-dessous, également retiré dans ce
                // cas). La page combinée historique (`fixedType == null`,
                // `/production/summary`, jamais visée par ce ticket) garde
                // ces cartes strictement inchangées.
                if (widget.fixedType == null) ...[
                  _buildKpiRow(context, isMobile),
                  const SizedBox(height: 26),
                ],
                if (_loading && promesh == null && probar == null)
                  _buildTablesSkeleton()
                else ...[
                  // 4. Section PROMESH
                  if (promesh != null) ...[
                    _ProductionSection(
                      titleKey: 'Production PROMESH',
                      totalLabelKey: 'Total PROMESH',
                      color: kPromeshColor,
                      icon: Icons.factory_outlined,
                      table: promesh,
                      isPromesh: true,
                      sort: _promeshSort,
                      onSortChanged: (s) => setState(() => _promeshSort = s),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // 5. Section PROBAR
                  if (probar != null) ...[
                    _ProductionSection(
                      titleKey: 'Production PROBAR',
                      totalLabelKey: 'Total PROBAR',
                      color: kProbarColor,
                      icon: Icons.factory_outlined,
                      table: probar,
                      isPromesh: false,
                      sort: _probarSort,
                      onSortChanged: (s) => setState(() => _probarSort = s),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // §SUPPRESSION — TABLEAUX "TOTAL PAR JOURNÉE" (2026-09-08,
                  // ticket "supprimer complètement les deux tableaux de
                  // synthèse") — les sections PROMESH/PROBAR "Total par
                  // journée" (et toute leur logique d'agrégation dédiée,
                  // `DailyProductionTotal`/`_aggregateDailyTotals`/
                  // `_DailyTotalsSection`/`_DailyTotalsTableCard`/
                  // `_PromeshDailyBreakdownCard`) ont été entièrement
                  // retirées — seuls les tableaux détaillés PROMESH/PROBAR
                  // Production (`_ProductionSection` ci-dessus) subsistent.
                  if (promesh == null && probar == null) _buildEmpty(context, t),
                ],
              ],
              // 6. Export (toujours en tout dernier, après les deux tableaux)
              _buildExportBar(context),
            ]),
          ),
        ),
      ),
    );
  }

  // ── HEADER + EXPORTS ──────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isMobile) {
    final t = AppLocalizations.of(context);
    return Row(children: [
      Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: kCrmPrimary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.summarize_outlined, size: 22, color: kCrmPrimary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.translate(_pageTitleKey), style: tInter(fontSize: 21, fontWeight: FontWeight.w800, color: kCrmText)),
          const SizedBox(height: 2),
          Text(
            t.translate(_pageSubtitleKey),
            style: tInter(fontSize: 12.5, color: kCrmTextSub),
          ),
        ]),
      ),
      if (!isMobile) ...[
        IconButton(
          tooltip: t.translate('Actualiser'),
          icon: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh_rounded, size: 18, color: kCrmTextSub),
          onPressed: _loading ? null : _refreshAll,
        ),
      ],
    ]);
  }

  // Placé en tout dernier dans le flux de la page (voir build()) — après
  // les deux tableaux, jamais superposé au reste du contenu.
  Widget _buildExportBar(BuildContext context) {
    final t = AppLocalizations.of(context);
    // §11 : jamais d'export possible tant que le dernier chargement a échoué
    // — même si un précédent filtre avait chargé des données avec succès
    // (`_summary` garde alors sa dernière valeur connue, volontairement pas
    // effacée pour l'affichage), exporter ces données périmées pendant qu'une
    // erreur est affichée serait trompeur.
    final hasData = _error == null && (_summary.promesh != null || _summary.probar != null);
    Widget btn(IconData icon, String label, VoidCallback? onTap) => OutlinedButton.icon(
          onPressed: (_exporting || !hasData) ? null : onTap,
          icon: Icon(icon, size: 16),
          label: Text(t.translate(label), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: kCrmPrimary,
            side: const BorderSide(color: kCrmBorder),
            backgroundColor: kCrmBg,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCrmBorder)),
      child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        // §MODIFICATION — CORRECTION GLOBALE DES TRADUCTIONS (2026-09-17) —
        // le service d'export n'a pas de `BuildContext` propre (ce n'est
        // pas un widget) : on lui transmet directement la fonction
        // `translate` déjà résolue ICI (où `context` est disponible), pour
        // que Excel/PDF/Impression respectent la langue actuellement
        // sélectionnée — jamais un second système de traduction (§3 du
        // ticket).
        btn(
          Icons.table_view_rounded,
          'Export Excel',
          () => _runExport(() => ProductionSummaryExportService.instance
              .exportExcel(_sortedSummaryForExport, _exportContext, AppLocalizations.of(context).translate)),
        ),
        btn(
          Icons.picture_as_pdf_outlined,
          'Export PDF',
          () => _runExport(() => ProductionSummaryExportService.instance
              .exportPdf(_sortedSummaryForExport, _exportContext, AppLocalizations.of(context).translate)),
        ),
        btn(
          Icons.print_outlined,
          'Imprimer',
          () => _runExport(() => ProductionSummaryExportService.instance
              .printSummary(_sortedSummaryForExport, _exportContext, AppLocalizations.of(context).translate)),
        ),
        if (_exporting) ...[
          const SizedBox(width: 4),
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ]),
    );
  }

  // ── FILTRES (Type + Période + Diamètre + Machine + Statut + Reset) ─────

  Widget _buildFiltersCard(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCrmBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // §3/§13 du ticket : sur une page dédiée (fixedType défini), le
        // sélecteur "Toutes/PROMESH/PROBAR" n'a plus lieu d'être — la page
        // ne montre QUE le type verrouillé, jamais un moyen de basculer
        // vers l'autre type depuis cet écran. La page combinée historique
        // (`fixedType == null`) garde ce sélecteur, inchangé.
        if (widget.fixedType == null) ...[
          _buildTypeFilter(context),
          const SizedBox(height: 14),
        ],
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          // §MODIFICATION — PRODUCTION SUMMARY : FILTRE "CUSTOM DATE" UNIQUE
          // (2026-09-07) — remplace l'ancien dropdown Période ("Toutes/
          // Semaine/Mois/Personnalisée") + les deux chips "Date début"/"Date
          // fin" affichées séparément : UN SEUL contrôle, toujours visible.
          // §CORRECTION — SÉLECTION D'UNE SEULE DATE (2026-09-07, ticket
          // suivant) : filtre sur UN SEUL jour (`showDatePicker`), jamais une
          // plage — voir _customDateChip plus bas.
          _customDateChip(context),
          _dropdown<String?>(
            icon: Icons.circle_outlined,
            value: _diameterFilter,
            items: [
              (null, t.translate('Tous les diamètres')),
              for (final d in _filters.diameters) (d, '$d mm'),
            ],
            onChanged: (v) => setState(() {
              _diameterFilter = v;
              _onFilterChanged();
            }),
          ),
          _dropdown<String?>(
            icon: Icons.precision_manufacturing_outlined,
            value: _machineFilter,
            items: [
              (null, t.translate('Toutes les machines')),
              for (final m in _filters.machines) (m, '${t.translate('Machine')} $m'),
            ],
            onChanged: (v) => setState(() {
              _machineFilter = v;
              _onFilterChanged();
            }),
          ),
          _dropdown<String>(
            icon: Icons.fact_check_outlined,
            value: _status,
            items: [for (final s in _kStatuses) (s.$1, t.translate(s.$2))],
            onChanged: (v) => setState(() {
              _status = v!;
              _onFilterChanged();
            }),
          ),
          TextButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh_rounded, size: 16, color: kCrmTextSub),
            label: Text(t.translate('Réinitialiser'), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmTextSub)),
          ),
        ]),
      ]),
    );
  }

  // §MODIFICATION — CUSTOM DATE : DEUX MODES "DATE UNIQUE" / "PÉRIODE"
  // (2026-09-09) — remplace l'ancien tap unique (qui n'ouvrait QUE
  // `showDatePicker`) par un `PopupMenuButton` proposant explicitement les
  // deux modes (§3 du ticket) : "Date unique" ouvre `showDatePicker` (jour
  // unique, comportement inchangé du ticket précédent) ; "Période" ouvre
  // `showDateRangePicker` (§5 — SEULE l'action de choisir "Période" fait
  // apparaître Date début/Date fin, jamais affichées par défaut, §4 :
  // toujours absentes en mode Date unique). Les deux champs d'état
  // (_selectedDate/_selectedRange) sont mutuellement exclusifs : choisir
  // l'un efface systématiquement l'autre (§7 : Reset les efface tous les
  // deux également, voir _resetFilters).
  Widget _customDateChip(BuildContext context) {
    final t = AppLocalizations.of(context);
    final label = _customDateLabel(t);

    Future<void> pickSingleDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked == null) return;
      setState(() {
        _selectedDate = picked;
        _selectedRange = null;
      });
      _onFilterChanged();
    }

    Future<void> pickRange() async {
      final picked = await showDateRangePicker(
        context: context,
        initialDateRange: _selectedRange,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked == null) return;
      setState(() {
        _selectedRange = picked;
        _selectedDate = null;
      });
      _onFilterChanged();
    }

    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (mode) {
        if (mode == 'single') pickSingleDate();
        if (mode == 'range') pickRange();
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'single', child: Text(t.translate('Date unique'))),
        PopupMenuItem(value: 'range', child: Text(t.translate('Période'))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: kCrmTextSub),
          const SizedBox(width: 6),
          Text(label, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText)),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more_rounded, size: 16, color: kCrmTextSub),
        ]),
      ),
    );
  }

  // §8 du ticket — trois cas d'affichage distincts : aucune date ("Custom
  // Date"), date unique ("Custom Date : dd/MM/yyyy"), période ("Period :
  // dd/MM/yyyy - dd/MM/yyyy"). Même format de date que le reste de
  // l'application (dd/MM/yyyy, voir _formatProductionDate).
  String _customDateLabel(AppLocalizations t) {
    if (_selectedDate != null) {
      return '${t.translate('Custom Date')} : ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}';
    }
    if (_selectedRange != null) {
      final start = DateFormat('dd/MM/yyyy').format(_selectedRange!.start);
      final end = DateFormat('dd/MM/yyyy').format(_selectedRange!.end);
      // §CORRECTION — CLÉ DE TRADUCTION INCOHÉRENTE (2026-09-17) : ce même
      // libellé utilisait une clé DIFFÉRENTE ('Period') de celle du menu de
      // sélection ci-dessus ('Période') — deux clés pour le même concept
      // pouvaient diverger et mélanger les langues. Unifié sur 'Période'.
      return '${t.translate('Période')} : $start - $end';
    }
    return t.translate('Custom Date');
  }

  // ── FILTRE TYPE (segmenté) ───────────────────────────────────────────

  Widget _buildTypeFilter(BuildContext context) {
    final t = AppLocalizations.of(context);
    Widget seg(String? value, String label, Color color) {
      final active = _type == value;
      return InkWell(
        onTap: () => setState(() {
          _type = value;
          _onFilterChanged();
        }),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.12) : kCrmBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? color : kCrmBorder, width: active ? 1.4 : 1),
          ),
          child: Text(t.translate(label), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? color : kCrmTextSub)),
        ),
      );
    }

    return Wrap(spacing: 10, runSpacing: 10, children: [
      seg(null, 'Toutes les productions', kCrmPrimary),
      seg('promesh', 'PROMESH', kPromeshColor),
      seg('probar', 'PROBAR', kProbarColor),
    ]);
  }

  Widget _dropdown<T>({
    required IconData icon,
    required T value,
    required List<(T, String)> items,
    required ValueChanged<T?> onChanged,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.expand_more_rounded, size: 18, color: kCrmTextSub),
          style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText),
          selectedItemBuilder: (context) => [
            for (final item in items)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 14, color: kCrmTextSub),
                const SizedBox(width: 6),
                Text(item.$2, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText)),
              ]),
          ],
          items: [for (final item in items) DropdownMenuItem<T>(value: item.$1, child: Text(item.$2))],
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── KPI — jamais additionner m (PROBAR) et m² (PROMESH) : chaque unité a
  // sa propre carte, jamais combinées sur une même carte/valeur.
  //
  // Volontairement PAS de GridView.count/childAspectRatio ici : une hauteur
  // de cellule dérivée d'un ratio fixe peut devenir plus petite que le
  // contenu réel de la carte (libellés traduits plus longs, etc.), et le
  // Column déborde alors visuellement PAR-DESSUS ce qui suit (symptôme
  // "les KPI chevauchent les éléments en dessous"). `_responsiveCardGrid`
  // ci-dessous mesure la hauteur réelle du contenu (IntrinsicHeight) et
  // l'applique à toute la ligne (stretch) — largeur et hauteur toujours
  // identiques, jamais de débordement possible.
  // KPI calculés à partir des MÊMES lignes que le tableau ci-dessous
  // (promesh.grandTotal/probar.grandTotal/totalRecords — voir
  // ProductionSummaryTable) : jamais une valeur recalculée séparément,
  // jamais hardcodée.
  Widget _buildKpiRow(BuildContext context, bool isMobile) {
    final t = AppLocalizations.of(context);
    final promesh = _summary.promesh;
    final probar = _summary.probar;
    final width = MediaQuery.of(context).size.width;
    final columns = width < 700 ? 1 : (width < 1100 ? 2 : 3);

    if (_loading && promesh == null && probar == null) {
      return _responsiveCardGrid(List.generate(3, (_) => _kpiSkeletonCard()), columns);
    }

    final totalRecords = (promesh?.totalRecords ?? 0) + (probar?.totalRecords ?? 0);

    final cards = <Widget>[
      if (promesh != null)
        KpiStatCard(
          icon: Icons.factory_outlined,
          value: '${formatProductionNumber(promesh.grandTotal)} ${promesh.unit}',
          label: t.translate('Total PROMESH'),
          color: kPromeshColor,
        ),
      if (probar != null)
        KpiStatCard(
          icon: Icons.factory_outlined,
          value: '${formatProductionNumber(probar.grandTotal)} ${probar.unit}',
          label: t.translate('Total PROBAR'),
          color: kProbarColor,
        ),
      KpiStatCard(
        icon: Icons.description_outlined,
        value: '$totalRecords',
        label: t.translate('Nombre de fiches'),
        color: kCrmSuccess,
      ),
    ];

    return _responsiveCardGrid(cards, columns);
  }

  Widget _kpiSkeletonCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kCrmBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: const [
        ShimmerBox(width: 44, height: 44, borderRadius: BorderRadius.all(Radius.circular(12))),
        SizedBox(height: 24),
        ShimmerBox(width: 70, height: 22),
        SizedBox(height: 6),
        ShimmerBox(width: 100, height: 12),
      ]),
    );
  }

  // §7 : un échec réseau/API affiche un message clair + Retry — jamais un
  // KPI "0" ou une liste vide qui laisserait croire que la base ne contient
  // aucune fiche (voir le if (_error != null) dans build()).
  Widget _buildError(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, color: kCrmDanger, size: 36),
          const SizedBox(height: 10),
          Text(t.translate('Impossible de charger les données de production.'),
              textAlign: TextAlign.center, style: tInter(fontSize: 14, fontWeight: FontWeight.w700, color: kCrmText)),
          const SizedBox(height: 4),
          Text(_error ?? '', textAlign: TextAlign.center, style: tInter(fontSize: 11.5, color: kCrmTextSub)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(t.translate('Réessayer')),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(child: Text(t.translate('Aucune donnée pour ces filtres'), style: tInter(fontSize: 13, color: kCrmTextSub))),
    );
  }

  Widget _buildTablesSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCrmBorder)),
      child: Column(children: [
        for (int i = 0; i < 5; i++) ...[
          const ShimmerBox(width: double.infinity, height: 18),
          if (i < 4) const SizedBox(height: 12),
        ],
      ]),
    );
  }
}

// ── SECTION (titre "Production PROMESH/PROBAR" + pastille total + tableau)
// ─────────────────────────────────────────────────────────────────────────
class _ProductionSection extends StatelessWidget {
  final String titleKey;
  final String totalLabelKey;
  final Color color;
  final IconData icon;
  final ProductionSummaryTable table;
  final bool isPromesh;
  final ProductionRowSort? sort;
  final ValueChanged<ProductionRowSort?> onSortChanged;

  const _ProductionSection({
    required this.titleKey,
    required this.totalLabelKey,
    required this.color,
    required this.icon,
    required this.table,
    required this.isPromesh,
    required this.sort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Text(t.translate(titleKey), style: tInter(fontSize: 16, fontWeight: FontWeight.w800, color: kCrmText)),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.35))),
          child: Text('${t.translate(totalLabelKey)} : ${formatProductionNumber(table.grandTotal)} ${table.unit}',
              style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
        ),
      ]),
      const SizedBox(height: 12),
      ProductionSummaryTableCard(
        color: color,
        table: table,
        isPromesh: isPromesh,
        grandTotalLabelKey: totalLabelKey,
        sort: sort,
        onSortChanged: onSortChanged,
      ),
    ]);
  }
}
