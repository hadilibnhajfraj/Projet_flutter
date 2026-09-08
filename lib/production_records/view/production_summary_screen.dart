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
  // jamais l'état de tri PROBAR). Vit ICI (pas dans `_SummaryTableCardState`)
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
      _SummaryTableCard(
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

// ── TABLEAU RÉCAPITULATIF (un par type — PROMESH ou PROBAR) ────────────
//
// Style "rapport ERP" : une ligne par fiche réelle (id/date/machine/
// diamètre/cell size/quantité — voir ProductionRecordModel, même modèle que
// "Fiches de production", aucun champ inventé), total de la section très
// visible en bas. Une fiche PROMESH machine 4 (valeur réelle de la colonne
// `machine`, jamais la position de la ligne — voir isPromesh4Machine) est
// mise en évidence sur toute la ligne. Pagination locale par fiches quand il
// y en a beaucoup — l'export (Excel/PDF, voir
// _ProductionSummaryScreenState._sortedSummaryForExport) utilise toujours
// l'intégralité des lignes (retriées selon le tri actif, §16/§17 du ticket
// "tri"), jamais seulement la page actuellement affichée ici.
class _SummaryTableCard extends StatefulWidget {
  final Color color;
  final ProductionSummaryTable table;
  final bool isPromesh;
  final String grandTotalLabelKey;
  final ProductionRowSort? sort;
  final ValueChanged<ProductionRowSort?> onSortChanged;

  const _SummaryTableCard({
    required this.color,
    required this.table,
    required this.isPromesh,
    required this.grandTotalLabelKey,
    required this.sort,
    required this.onSortChanged,
  });

  @override
  State<_SummaryTableCard> createState() => _SummaryTableCardState();
}

class _SummaryTableCardState extends State<_SummaryTableCard> {
  static const _rowsPerPage = 15;
  int _page = 0;

  static const _flexIndex = 1;
  static const _flexDate = 3;
  static const _flexMachine = 3;
  // §MODIFICATION — PRODUCTION SUMMARY : COLONNE SHIFT (2026-09-07, §4/§5 du
  // ticket) — Date → Machine → Shift → Diameter → Cell size → Quantity →
  // Waste, même ordre que demandé. Colonne PUREMENT informative : jamais
  // utilisée comme filtre (§3/§9), jamais additionnée dans les totaux (§8).
  static const _flexShift = 2;
  static const _flexDiameter = 2;
  static const _flexMesh = 3;
  static const _flexQty = 3;
  // §MODIFICATION — PRODUCTION SUMMARY : AJOUT DU WASTE DEPUIS RECOVERABLES.
  static const _flexWaste = 3;

  static const _promesh4Bg = Color(0xFFFEF3C7); // amber-100 — distinct du bleu PROMESH, lisible
  static const _promesh4Border = Color(0xFFF59E0B); // kCrmWarning

  @override
  void didUpdateWidget(covariant _SummaryTableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Filtres changés → les fiches affichées ne correspondent plus forcément
    // à la page courante ; on revient toujours en page 1 pour éviter une
    // page vide.
    if (oldWidget.table.rows != widget.table.rows) _page = 0;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final rows = widget.table.rows;
    // §MODIFICATION — TRI DES TABLEAUX "PROMESH/PROBAR PRODUCTION"
    // (2026-09-11) — `displayRows` est la SEULE variable affectée par le tri
    // (§13/§14 du ticket : appliqué APRÈS les filtres déjà pris en compte
    // par `rows`, et AVANT la pagination ci-dessous — jamais un tri limité à
    // la page courante). `rows` (non trié) reste utilisé TEL QUEL par
    // `_machineBreakdownBlock`/`_grandTotalRow`/`_grandTotalWasteRow`
    // ci-dessous : le tri d'affichage ne modifie jamais le récapitulatif ni
    // les totaux (§15).
    final displayRows = sortProductionRows(rows, column: widget.sort?.column, ascending: widget.sort?.ascending ?? true);
    final totalPages = displayRows.isEmpty ? 1 : ((displayRows.length + _rowsPerPage - 1) ~/ _rowsPerPage);
    final page = _page.clamp(0, totalPages - 1);
    final pageRows = displayRows.skip(page * _rowsPerPage).take(_rowsPerPage).toList();
    final showPagination = displayRows.length > _rowsPerPage;

    return Container(
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCrmBorder)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Center(child: Text(t.translate('Aucune donnée pour ces filtres'), style: tInter(fontSize: 12.5, color: kCrmTextSub))),
          )
        else
          // IMPORTANT : `ConstrainedBox(minWidth: ...)` seul NE BORNE PAS la
          // largeur maximale (maxWidth reste infini) — dans un
          // SingleChildScrollView horizontal, cela laisse les Row/Expanded
          // ci-dessous (_headerRow/_dataRow/_grandTotalRow)
          // avec une largeur non bornée, ce que Flutter refuse de layouter
          // (RenderFlex avec flex non nul sous contrainte de largeur
          // infinie) — le tableau entier disparaissait silencieusement,
          // laissant un grand espace vide entre les KPI et les boutons
          // d'export. `LayoutBuilder` + `SizedBox(width: ...)` donne une
          // largeur réellement bornée (au moins la largeur disponible, plus
          // si nécessaire sur mobile pour permettre le défilement — jamais
          // de hauteur fixe trop petite, chaque ligne garde sa hauteur
          // intrinsèque).
          LayoutBuilder(builder: (context, constraints) {
            final tableWidth = constraints.maxWidth < 620 ? 620.0 : constraints.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _headerRow(t),
                  for (int i = 0; i < pageRows.length; i++) _dataRow(t, page * _rowsPerPage + i + 1, pageRows[i]),
                  // §MODIFICATION — PRODUCTION SUMMARY : SYNTHÈSE PAR MACHINE
                  // À L'INTÉRIEUR DE "PROMESH PRODUCTION" (2026-09-08, ticket
                  // "ajouter cette synthèse JUSTE AVANT TOTAL PROMESH") —
                  // UNIQUEMENT pour PROMESH (jamais PROBAR, jamais une
                  // nouvelle section/page). Basée sur `widget.table.rows` EN
                  // ENTIER (le même jeu déjà filtré par le backend qui
                  // alimente aussi `_grandTotalRow` juste en dessous), donc
                  // TOUJOURS le total de TOUTES les pages, jamais seulement
                  // la page actuellement affichée — cohérent avec TOTAL
                  // PROMESH qui, lui aussi, porte déjà sur l'ensemble filtré.
                  if (widget.isPromesh) _machineBreakdownBlock(t),
                  _grandTotalRow(t),
                  // §MODIFICATION — PRODUCTION SUMMARY : AJOUT DU WASTE DEPUIS
                  // RECOVERABLES — deuxième ligne de total, sous TOTAL
                  // PROMESH/PROBAR (§6/§7 du ticket), jamais fusionnée avec la
                  // quantité (unités différentes, §8 : jamais mélangées).
                  _grandTotalWasteRow(t),
                ]),
              ),
            );
          }),
        if (showPagination) _buildPagination(t, page, totalPages),
      ]),
    );
  }

  Widget _headerRow(AppLocalizations t) {
    return Container(
      color: kCrmBg,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(children: [
        Expanded(flex: _flexIndex, child: _sortableHeader(t, '#', ProductionSortColumn.rowNumber)),
        Expanded(flex: _flexDate, child: _sortableHeader(t, t.translate('Date production'), ProductionSortColumn.date)),
        // §MODIFICATION — PRODUCTION SUMMARY : AJOUT DU WASTE DEPUIS
        // RECOVERABLES (§2) — "Machine" est désormais affiché pour PROBAR
        // aussi, plus seulement PROMESH.
        Expanded(flex: _flexMachine, child: _sortableHeader(t, t.translate('Machine'), ProductionSortColumn.machine)),
        Expanded(flex: _flexShift, child: _sortableHeader(t, t.translate('Shift'), ProductionSortColumn.shift)),
        Expanded(flex: _flexDiameter, child: _sortableHeader(t, t.translate('Diameter'), ProductionSortColumn.diameter)),
        if (widget.isPromesh)
          Expanded(flex: _flexMesh, child: _sortableHeader(t, t.translate('Cell size'), ProductionSortColumn.cellSize)),
        Expanded(
          flex: _flexQty,
          child: _sortableHeader(t, '${t.translate('Quantity')} (${widget.table.unit})', ProductionSortColumn.quantity, alignRight: true),
        ),
        Expanded(
          flex: _flexWaste,
          child: _sortableHeader(t, '${t.translate('Waste')} (${widget.table.wasteUnit})', ProductionSortColumn.waste, alignRight: true),
        ),
      ]),
    );
  }

  static final _headStyle = tInter(fontSize: 11, fontWeight: FontWeight.w800, color: kCrmTextSub, letterSpacing: 0.3);

  // §MODIFICATION — TRI DES TABLEAUX "PROMESH/PROBAR PRODUCTION"
  // (2026-09-11) — header cliquable, tri intégré directement dans l'en-tête
  // (§20 du ticket : "pas de gros boutons de tri", interface compacte).
  // Icône discrète : `unfold_more` (non trié) / `arrow_upward` (croissant) /
  // `arrow_downward` (décroissant) — §3 du ticket. La colonne active est mise
  // en évidence (couleur primaire, icône + libellé) pour rester "clairement
  // identifiable" (§3).
  Widget _sortableHeader(AppLocalizations t, String label, ProductionSortColumn column, {bool alignRight = false}) {
    final isActive = widget.sort?.column == column;
    final icon = !isActive
        ? Icons.unfold_more_rounded
        : (widget.sort!.ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);
    final style = isActive ? _headStyle.copyWith(color: kCrmPrimary) : _headStyle;
    final iconWidget = Icon(icon, size: 13, color: isActive ? kCrmPrimary : kCrmTextSub);
    final textWidget = Flexible(child: Text(label, style: style, overflow: TextOverflow.ellipsis));

    return InkWell(
      onTap: () => widget.onSortChanged(cycleProductionSort(widget.sort, column)),
      borderRadius: BorderRadius.circular(4),
      child: Row(
        mainAxisAlignment: alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [textWidget, const SizedBox(width: 3), iconWidget],
      ),
    );
  }

  Widget _dataRow(AppLocalizations t, int index, ProductionRecordModel r) {
    final isPromesh4 = widget.isPromesh && isPromesh4Machine(r.machine);
    final dateLabel = _formatProductionDate(r.date);
    final machineLabel = widget.isPromesh ? formatPromeshMachineLabel(r.machine) : formatProbarMachineLabel(r.machine);
    final diameterLabel = _diameterLabel(t, r.diametre);
    final meshLabel = _cellSizeLabel(t, r.tailleMaille);
    final qtyLabel = '${formatProductionNumber(r.quantite ?? 0)} ${widget.table.unit}';
    // §MODIFICATION — PRODUCTION SUMMARY : AJOUT DU WASTE DEPUIS RECOVERABLES
    // — `r.waste` vient directement du backend (jointure module+date sur
    // Recuperables.waste, voir productionRecords.service.js#attachWaste),
    // jamais recalculé ici à partir de Quantity/Diameter (§15). Absent → 0
    // (§5, jamais null/undefined/NaN affiché).
    final wasteLabel = '${r.waste.toStringAsFixed(2)} ${widget.table.wasteUnit}';

    final textStyle = tInter(fontSize: 12.5, fontWeight: isPromesh4 ? FontWeight.w700 : FontWeight.w500, color: kCrmText);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: isPromesh4 ? _promesh4Bg : null,
        border: Border(
          bottom: const BorderSide(color: kCrmBorder, width: 0.6),
          left: isPromesh4 ? const BorderSide(color: _promesh4Border, width: 3) : BorderSide.none,
        ),
      ),
      child: Row(children: [
        Expanded(flex: _flexIndex, child: Text('$index', style: textStyle)),
        Expanded(flex: _flexDate, child: Text(dateLabel, style: textStyle)),
        Expanded(
          flex: _flexMachine,
          child: isPromesh4 ? _promesh4Badge(r.machine) : Text(machineLabel, style: textStyle),
        ),
        Expanded(flex: _flexShift, child: _shiftBadge(r.poste)),
        Expanded(flex: _flexDiameter, child: Text(diameterLabel, style: textStyle)),
        if (widget.isPromesh) Expanded(flex: _flexMesh, child: Text(meshLabel, style: textStyle)),
        Expanded(flex: _flexQty, child: Text(qtyLabel, textAlign: TextAlign.right, style: textStyle)),
        Expanded(flex: _flexWaste, child: Text(wasteLabel, textAlign: TextAlign.right, style: textStyle)),
      ]),
    );
  }

  // Badge coloré pour la machine PROMESH 4 (§3 : "le badge Machine peut
  // également être coloré") — même couleur que la mise en évidence de ligne
  // (_promesh4Border), texte toujours parfaitement lisible.
  Widget _promesh4Badge(String? machine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _promesh4Border,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(formatPromeshMachineLabel(machine),
          style: tInter(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }

  // §CORRECTION — SYNTHÈSE PAR MACHINE : PRÉSENTATION "FICHE INDUSTRIELLE"
  // (2026-09-08, ticket "améliorer fortement l'affichage") — MÊME logique
  // fonctionnelle qu'avant (`_aggregateByMachine`, inchangée), seule la
  // PRÉSENTATION change : une petite "carte" compacte par machine (header +
  // mini-tableau Diameter/Cell size/Quantity/Waste + sous-total), plus le
  // grand tableau détaillé rejoué en colonnes complètes (§16 du ticket :
  // "la machine doit être un HEADER DE GROUPE", jamais répétée sur chaque
  // ligne interne). Volontairement INDÉPENDANTE des colonnes flex du
  // tableau détaillé ci-dessus (_flexIndex/_flexDate/...) — c'est justement
  // ce ré-emploi qui donnait l'impression d'un "second tableau mal
  // intégré" avant cette correction.
  static final _miniHeadStyle = tInter(fontSize: 10.5, fontWeight: FontWeight.w700, color: kCrmTextSub, letterSpacing: 0.2);
  static final _miniValueStyle = tInter(fontSize: 12.5, fontWeight: FontWeight.w500, color: kCrmText);

  // §MODIFICATION — RÉCAPITULATIF PROMESH 1-2-3 : SUPPRESSION DE LA COLONNE
  // MACHINE (2026-09-20, ticket "supprimer complètement la colonne
  // Machine") — la répartition PROMESH 4 / reste des machines continue de
  // s'appuyer sur `aggregateByMachine` (INCHANGÉE — toujours nécessaire pour
  // isoler PROMESH 4 via `isPromesh4Machine`, jamais hardcodé "1,2,3"), mais
  // les lignes du bloc "PROMESH 1+2+3" ne viennent PLUS de ces sections
  // par-machine : elles sont recalculées par `aggregateByDiameterCellSize`
  // sur les lignes BRUTES des machines non-4 (§2/§3 du ticket — GROUP BY
  // Diameter+Cell size UNIQUEMENT, jamais Machine — deux machines
  // différentes partageant le même Diameter+Cell size fusionnent désormais
  // en une seule ligne). `combinedMachineNumbers` (extrait des lignes
  // BRUTES, plus des groupes qui ne portent plus l'info machine) sert
  // uniquement à composer le libellé d'en-tête/sous-total "PROMESH 1-2-3".
  //
  // §CORRECTION — EXCLUSION DES LIGNES "NOT SPECIFIED" (2026-09-21, ticket
  // "corriger l'affichage du Production Summary") — `validRows` retire
  // RÉELLEMENT (jamais un masquage visuel) toute fiche dont Diameter OU
  // Cell size est absent/vide AVANT tout regroupement (§1/§4/§9 du ticket).
  // Le tableau détaillé "PROMESH Production" (`widget.table.rows`, jamais
  // référencé ci-dessous) continue d'afficher CES mêmes fiches intactes —
  // seul le récapitulatif filtre (§8 du ticket).
  Widget _machineBreakdownBlock(AppLocalizations t) {
    final validRows = widget.table.rows.where(hasValidDiameterAndCellSize).toList();
    final sections = aggregateByMachine(validRows, groupByCellSize: widget.isPromesh);
    if (sections.isEmpty) return const SizedBox.shrink();

    final isolatedSections = [
      for (final s in sections)
        if (isPromesh4Machine(s.machine)) s,
    ];
    final combinedRows = validRows.where((r) => !isPromesh4Machine(r.machine)).toList();
    final combinedGroups = aggregateByDiameterCellSize(combinedRows);
    final combinedMachineNumbers = <String>{
      for (final r in combinedRows)
        if (r.machine != null && r.machine!.trim().isNotEmpty) r.machine!.trim(),
    }.toList()
      ..sort((a, b) {
        final na = int.tryParse(a);
        final nb = int.tryParse(b);
        if (na != null && nb != null) return na.compareTo(nb);
        return a.compareTo(b);
      });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: const BoxDecoration(
        color: kCrmBg,
        border: Border(top: BorderSide(color: kCrmBorder), bottom: BorderSide(color: kCrmBorder)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.translate('Récapitulatif de production').toUpperCase(),
            style: tInter(fontSize: 11, fontWeight: FontWeight.w800, color: kCrmTextSub, letterSpacing: 0.6)),
        const SizedBox(height: 10),
        if (combinedGroups.isNotEmpty) ...[
          _combinedMachineCard(t, combinedGroups, combinedMachineNumbers),
          if (isolatedSections.isNotEmpty) const SizedBox(height: 10),
        ],
        for (var i = 0; i < isolatedSections.length; i++) ...[
          _machineCard(t, isolatedSections[i]),
          if (i < isolatedSections.length - 1) const SizedBox(height: 10),
        ],
      ]),
    );
  }

  // §1/§5 du ticket : UNE SEULE carte pour PROMESH 1+2+3, avec EXACTEMENT
  // les mêmes 4 colonnes que la carte PROMESH 4 isolée (`_machineCard`) —
  // Diameter | Cell size | Quantity | Waste, JAMAIS de colonne Machine
  // (§1 du ticket). `groups` arrive déjà trié Diameter → Cell size (§6,
  // produit par `aggregateByDiameterCellSize`, jamais retrié ici) ;
  // `machineNumbers` (extrait des lignes brutes par l'appelant) sert
  // uniquement au libellé d'en-tête/sous-total, jamais au regroupement.
  Widget _combinedMachineCard(AppLocalizations t, List<MachineDiameterGroup> groups, List<String> machineNumbers) {
    final subtotal = groups.fold<double>(0, (sum, g) => sum + g.quantity);
    // Simple somme des `waste` DÉJÀ calculés par groupe (voir
    // `MachineDiameterGroup.waste`, produit par `aggregateByDiameterCellSize`,
    // jamais retouché ici) — jamais un recalcul à partir de Quantity (§4 du
    // ticket), jamais le total général (`table.grandTotalWaste`, réservé au
    // bandeau TOTAL WASTE final, voir _grandTotalWasteRow, INCHANGÉ).
    final wasteSubtotal = groups.fold<double>(0, (sum, g) => sum + g.waste);
    final headerLabel = machineNumbers.isEmpty
        ? AppLocalizations.of(context).translate('Non renseigné')
        : machineNumbers.map(formatPromeshMachineLabel).join(' + ');
    // "SOUS-TOTAL PROMESH 1-2-3" (jamais "TOTAL", réservé au grand total
    // final déjà existant en bas du tableau — voir _grandTotalRow, INCHANGÉ).
    final totalLabel = machineNumbers.isEmpty ? '' : 'PROMESH ${machineNumbers.join('-')}';

    return Container(
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          color: kCrmSurface,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(children: [
            Icon(Icons.precision_manufacturing_outlined, size: 15, color: widget.color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(headerLabel,
                  style: tInter(fontSize: 13.5, fontWeight: FontWeight.w700, color: widget.color), overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
        Container(height: 1, color: kCrmBorder),
        // Mini-header — EXACTEMENT les mêmes 4 colonnes/poids que la carte
        // PROMESH 4 isolée ci-dessous (_machineCard) : plus aucune colonne
        // Machine (§1 du ticket).
        Container(
          color: kCrmBg,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(children: [
            Expanded(flex: 2, child: Text(t.translate('Diameter'), style: _miniHeadStyle)),
            Expanded(flex: 3, child: Text(t.translate('Cell size'), style: _miniHeadStyle)),
            Expanded(flex: 3, child: Text(t.translate('Quantity'), style: _miniHeadStyle, textAlign: TextAlign.right)),
            Expanded(flex: 2, child: Text(t.translate('Waste'), style: _miniHeadStyle, textAlign: TextAlign.right)),
          ]),
        ),
        // Réutilise TEL QUEL `_machineDetailRow` (même structure Diameter/
        // Cell size/Quantity/Waste que la carte PROMESH 4 isolée) — plus de
        // widget dédié séparé nécessaire depuis la suppression de la
        // colonne Machine.
        for (final g in groups) _machineDetailRow(t, g),
        // §7 du ticket : UN SEUL total pour l'ensemble de la section
        // (jamais un sous-total par machine à l'intérieur de cette carte) —
        // "SOUS-TOTAL PROMESH 1-2-3", jamais confondu avec le TOTAL PROMESH
        // final (couleur pleine, voir _grandTotalRow) qui, lui, inclut
        // PROMESH 4. Le libellé occupe la largeur des colonnes Diameter+
        // Cell size (flex 2+3=5, mêmes poids que le mini-header ci-dessus),
        // Quantity (flex 3) et Waste (flex 2) restent chacune alignées à
        // droite sous leur propre colonne.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          color: widget.color.withOpacity(0.06),
          child: Row(children: [
            Expanded(
              flex: 5,
              child: Text(totalLabel.isEmpty ? t.translate('SOUS-TOTAL') : '${t.translate('SOUS-TOTAL')} $totalLabel',
                  style: tInter(fontSize: 12, fontWeight: FontWeight.w600, color: kCrmText)),
            ),
            Expanded(
              flex: 3,
              child: Text('${formatProductionNumber(subtotal)} ${widget.table.unit}',
                  textAlign: TextAlign.right, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: widget.color)),
            ),
            Expanded(
              flex: 2,
              child: Text('${wasteSubtotal.toStringAsFixed(2)} ${widget.table.wasteUnit}',
                  textAlign: TextAlign.right, style: tInter(fontSize: 12, fontWeight: FontWeight.w600, color: kCrmTextSub)),
            ),
          ]),
        ),
      ]),
    );
  }

  // Carte compacte pour une machine "isolée" (PROMESH 4, jamais une autre
  // depuis le regroupement 1-2-3, voir _machineBreakdownBlock ci-dessus) —
  // header (icône + badge) puis mini-tableau Diameter/Cell size/Quantity/
  // Waste (pas de colonne Machine ici : une seule machine, §7 du ticket),
  // puis total. PROMESH 4 ne reçoit JAMAIS de grand bandeau orange ici — la
  // carte garde le même style neutre que la section combinée, seul le badge
  // dans le header (_promesh4Badge, déjà existant, inchangé) reste orange
  // (§6 du ticket).
  Widget _machineCard(AppLocalizations t, MachineSection s) {
    final subtotal = s.rows.fold<double>(0, (sum, r) => sum + r.quantity);
    // §6 du ticket "corriger SOUS-TOTAL PROMESH 1-2" — même règle que
    // _combinedMachineCard : simple somme des `waste` déjà calculés par
    // groupe (jamais un recalcul, jamais le total général).
    final wasteSubtotal = s.rows.fold<double>(0, (sum, r) => sum + r.waste);
    return Container(
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header — la machine apparaît ICI une seule fois (§5 du ticket),
        // jamais répétée sur les lignes internes.
        Container(
          width: double.infinity,
          color: kCrmSurface,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(children: [
            Icon(Icons.precision_manufacturing_outlined, size: 15, color: widget.color),
            const SizedBox(width: 8),
            _machineSectionLabel(s.machine),
          ]),
        ),
        Container(height: 1, color: kCrmBorder),
        // Mini-header de colonnes — propre à cette carte, jamais aligné sur
        // les colonnes du tableau détaillé (§16 : éviter le "second
        // tableau mal intégré").
        Container(
          color: kCrmBg,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(children: [
            Expanded(flex: 2, child: Text(t.translate('Diameter'), style: _miniHeadStyle)),
            Expanded(flex: 3, child: Text(t.translate('Cell size'), style: _miniHeadStyle)),
            Expanded(flex: 3, child: Text(t.translate('Quantity'), style: _miniHeadStyle, textAlign: TextAlign.right)),
            Expanded(flex: 2, child: Text(t.translate('Waste'), style: _miniHeadStyle, textAlign: TextAlign.right)),
          ]),
        ),
        for (final g in s.rows) _machineDetailRow(t, g),
        // §7/§9 du ticket "Excel de référence" : "SOUS-TOTAL PROMESH 4" —
        // mis en évidence, mais nettement plus discret que le TOTAL PROMESH
        // final (bandeau bleu plein, voir _grandTotalRow, INCHANGÉ).
        //
        // §MODIFICATION — COLONNES QUANTITY/WASTE SÉPARÉES (2026-09-14) —
        // le libellé occupe la largeur des colonnes Diameter+Cell size
        // (flex 2+3=5, mêmes poids que le mini-header ci-dessus), Quantity
        // (flex 3) et Waste (flex 2) sont chacune alignées à droite sous
        // leur propre colonne (§3/§4/§6 du ticket).
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          color: widget.color.withOpacity(0.06),
          child: Row(children: [
            Expanded(
              flex: 5,
              child: Text('${t.translate('SOUS-TOTAL')} ${formatPromeshMachineLabel(s.machine)}',
                  style: tInter(fontSize: 12, fontWeight: FontWeight.w600, color: kCrmText)),
            ),
            Expanded(
              flex: 3,
              child: Text('${formatProductionNumber(subtotal)} ${widget.table.unit}',
                  textAlign: TextAlign.right, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: widget.color)),
            ),
            Expanded(
              flex: 2,
              child: Text('${wasteSubtotal.toStringAsFixed(2)} ${widget.table.wasteUnit}',
                  textAlign: TextAlign.right, style: tInter(fontSize: 12, fontWeight: FontWeight.w600, color: kCrmTextSub)),
            ),
          ]),
        ),
      ]),
    );
  }

  // §"PROMESH 4" du ticket : le badge orange n'apparaît QUE sur le libellé
  // de la machine, jamais sur toute la carte/ligne — les autres machines
  // restent en texte normal (couleur PROMESH déjà utilisée pour les
  // quantités du tableau, pour rester identifiables sans inventer un
  // nouveau style). Titre légèrement plus grand que les valeurs internes
  // (§12 : "Titre machine : font-size légèrement supérieur, font-weight
  // 600/700").
  Widget _machineSectionLabel(String? machine) {
    if (machine == null || machine.isEmpty) {
      return Text(AppLocalizations.of(context).translate('Non renseigné'),
          style: tInter(fontSize: 13, fontWeight: FontWeight.w700, color: kCrmTextSub));
    }
    if (isPromesh4Machine(machine)) return _promesh4Badge(machine);
    return Text(formatPromeshMachineLabel(machine), style: tInter(fontSize: 13.5, fontWeight: FontWeight.w700, color: widget.color));
  }

  Widget _machineDetailRow(AppLocalizations t, MachineDiameterGroup g) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder, width: 0.4))),
      child: Row(children: [
        Expanded(flex: 2, child: Text(_diameterLabel(t, g.diametre), style: _miniValueStyle)),
        Expanded(flex: 3, child: Text(_cellSizeLabel(t, g.cellSize), style: _miniValueStyle)),
        Expanded(
          flex: 3,
          child: Text('${formatProductionNumber(g.quantity)} ${widget.table.unit}',
              textAlign: TextAlign.right, style: _miniValueStyle.copyWith(fontWeight: FontWeight.w700, color: widget.color)),
        ),
        Expanded(
          flex: 2,
          child: Text('${g.waste.toStringAsFixed(2)} ${widget.table.wasteUnit}',
              textAlign: TextAlign.right, style: _miniValueStyle.copyWith(color: kCrmTextSub)),
        ),
      ]),
    );
  }

  // §MODIFICATION — PRODUCTION SUMMARY : COLONNE SHIFT (2026-09-07, §4-§7 du
  // ticket) — badge PUREMENT informatif, jamais un filtre (§3/§9, aucun
  // dropdown Shift n'existe). Lit directement `r.poste` ('matin'/'nuit',
  // valeur métier RÉELLE déjà stockée en base pour PROMESH ET PROBAR — voir
  // le champ `poste` dans PorPromesh.js/IndustrialRecord.js, ENUM("matin",
  // "nuit")) : aucune valeur inventée, aucun "Shift 1/2/3" (§6). Une fiche
  // sans poste enregistré (anciennes données, §7) affiche "Non renseigné" —
  // même convention que Diameter/Cell size juste à côté dans ce même
  // tableau, jamais un poste deviné.
  //
  // "Soir" est le libellé d'AFFICHAGE retenu ici pour la valeur backend
  // 'nuit' (PROMESH ET PROBAR, conformément aux exemples du ticket) — la
  // valeur métier stockée reste 'nuit', jamais renommée en base ; seul le
  // libellé affiché change (§4 : "faire uniquement le mapping d'affichage
  // nécessaire").
  Widget _shiftBadge(String? poste) {
    final t = AppLocalizations.of(context);
    if (poste != 'matin' && poste != 'nuit') {
      return Text(t.translate('Non renseigné'), style: tInter(fontSize: 11.5, color: kCrmTextSub));
    }
    final isMatin = poste == 'matin';
    final color = isMatin ? kCrmInfo : kCrmWarning;
    final label = isMatin ? t.translate('Matin') : t.translate('Soir');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(label, style: tInter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // §CORRECTION — EXCLUSION DES LIGNES "NOT SPECIFIED" (2026-09-21, ticket
  // "corriger l'affichage du Production Summary") — §7 du ticket : "TOTAL
  // PROMESH doit être calculé uniquement à partir des lignes valides
  // affichées dans les deux blocs" = SOUS-TOTAL PROMESH 1-2-3 + SOUS-TOTAL
  // PROMESH 4 (mêmes `validRows` que _machineBreakdownBlock/
  // _recapWasteTotal). PROBAR (aucun récapitulatif affiché, jamais concerné
  // par ce ticket) garde `table.grandTotal` inchangé.
  //
  // IMPORTANT — CHANGEMENT DE COMPORTEMENT VISIBLE : avant cette correction,
  // "TOTAL PROMESH" incluait TOUTE la quantité de `table.grandTotal`
  // (valeur backend, y compris les fiches sans Diameter/Cell size
  // renseignés). Il n'inclut désormais QUE la quantité des fiches valides —
  // une fiche réelle mais sans Diameter/Cell size ne contribue plus du tout
  // à ce total, exactement comme demandé explicitement par ce ticket.
  double _recapQuantityTotal() {
    final validRows = widget.table.rows.where(hasValidDiameterAndCellSize).toList();
    final sections = aggregateByMachine(validRows, groupByCellSize: true);
    final isolatedQty = sections
        .where((s) => isPromesh4Machine(s.machine))
        .expand((s) => s.rows)
        .fold<double>(0, (sum, g) => sum + g.quantity);
    final combinedRows = validRows.where((r) => !isPromesh4Machine(r.machine)).toList();
    final combinedQty = aggregateByDiameterCellSize(combinedRows).fold<double>(0, (sum, g) => sum + g.quantity);
    return isolatedQty + combinedQty;
  }

  Widget _grandTotalRow(AppLocalizations t) {
    final leadingFlex = _flexIndex + _flexDate + _flexMachine + _flexShift + _flexDiameter + (widget.isPromesh ? _flexMesh : 0);
    final qtyTotal = widget.isPromesh ? _recapQuantityTotal() : widget.table.grandTotal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(color: widget.color),
      child: Row(children: [
        Expanded(
          flex: leadingFlex,
          child: Text(t.translate(widget.grandTotalLabelKey).toUpperCase(),
              style: tInter(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.4)),
        ),
        Expanded(
          flex: _flexQty,
          child: Text('${formatProductionNumber(qtyTotal)} ${widget.table.unit}',
              textAlign: TextAlign.right, style: tInter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
        // Colonne Waste laissée vide sur cette ligne — son propre total
        // s'affiche sur la ligne dédiée juste en dessous (_grandTotalWasteRow,
        // §6/§7 : jamais mélangé avec Quantity, unités différentes).
        Expanded(flex: _flexWaste, child: const SizedBox.shrink()),
      ]),
    );
  }

  // §CORRECTION — INCOHÉRENCE SOUS-TOTAUX/TOTAL WASTE PROMESH (2026-09-19,
  // ticket "corriger le calcul du Waste dans Production Summary — PROMESH")
  // — AVANT cette correction, "TOTAL WASTE" affichait `table.grandTotalWaste`
  // (calculé côté backend en comptant chaque DATE une seule fois sur
  // L'ENSEMBLE du tableau), alors que les sous-totaux du récapitulatif
  // (`_combinedMachineCard`/`_machineCard`, voir `_recapWasteTotal`
  // ci-dessous) comptent chaque date une seule fois PAR GROUPE
  // (Machine+Diameter+Cell size) — deux méthodes de calcul différentes pour
  // la "même" valeur, d'où l'écart observé (ex. 3 750 + 0 dans les
  // sous-totaux contre 750 dans le total, quand une même date de production
  // contribue à plusieurs groupes distincts).
  //
  // Le ticket demande explicitement UNE SEULE source de vérité :
  // TOTAL WASTE PROMESH = SOUS-TOTAL PROMESH 1-2(-3) + SOUS-TOTAL PROMESH 4.
  // Pour PROMESH, "TOTAL WASTE" est donc désormais recalculé à partir des
  // MÊMES groupes que le récapitulatif (`aggregateByMachine`, jamais une
  // valeur backend indépendante ni un recalcul depuis Quantity/Diameter/Cell
  // size — §4/§5/§6/§7 du ticket) : par construction, il est alors
  // TOUJOURS exactement égal à la somme des sous-totaux affichés au-dessus.
  // PROBAR (aucun récapitulatif/sous-total affiché pour ce type, voir
  // _machineBreakdownBlock ci-dessus, gate `if (widget.isPromesh)`) garde
  // `table.grandTotalWaste` inchangé — rien à réconcilier puisqu'aucun
  // sous-total n'est montré à l'écran pour PROBAR.
  // §MISE À JOUR — SUPPRESSION COLONNE MACHINE DU BLOC 1-2-3 (2026-09-20) —
  // depuis que le bloc "PROMESH 1+2+3" est recalculé par
  // `aggregateByDiameterCellSize` (jamais `aggregateByMachine`, voir
  // _machineBreakdownBlock), ce total DOIT suivre EXACTEMENT la même
  // logique pour rester la somme réelle des sous-totaux affichés (sinon on
  // réintroduit la même incohérence que la correction précédente, vue sous
  // un autre angle) : PROMESH 4 (isolé, via `aggregateByMachine` — jamais
  // changé, une seule machine) + le reste (PROMESH 1-2-3, via
  // `aggregateByDiameterCellSize` sur les lignes brutes non-PROMESH 4).
  double _recapWasteTotal() {
    // §CORRECTION — EXCLUSION DES LIGNES "NOT SPECIFIED" (2026-09-21) — même
    // filtre `validRows` que `_machineBreakdownBlock` (§2/§7 du ticket :
    // "Not specified" ne doit avoir AUCUN impact sur le total), pour que ce
    // total reste la somme exacte des sous-totaux réellement affichés.
    final validRows = widget.table.rows.where(hasValidDiameterAndCellSize).toList();
    final sections = aggregateByMachine(validRows, groupByCellSize: true);
    final isolatedWaste = sections
        .where((s) => isPromesh4Machine(s.machine))
        .expand((s) => s.rows)
        .fold<double>(0, (sum, g) => sum + g.waste);
    final combinedRows = validRows.where((r) => !isPromesh4Machine(r.machine)).toList();
    final combinedWaste = aggregateByDiameterCellSize(combinedRows).fold<double>(0, (sum, g) => sum + g.waste);
    return isolatedWaste + combinedWaste;
  }

  Widget _grandTotalWasteRow(AppLocalizations t) {
    final leadingFlex = _flexIndex + _flexDate + _flexMachine + _flexShift + _flexDiameter + (widget.isPromesh ? _flexMesh : 0) + _flexQty;
    final wasteTotal = widget.isPromesh ? _recapWasteTotal() : widget.table.grandTotalWaste;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(color: widget.color.withOpacity(0.85)),
      child: Row(children: [
        Expanded(
          flex: leadingFlex,
          child: Text(t.translate('TOTAL WASTE'),
              style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.4)),
        ),
        Expanded(
          flex: _flexWaste,
          child: Text('${wasteTotal.toStringAsFixed(2)} ${widget.table.wasteUnit}',
              textAlign: TextAlign.right, style: tInter(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      ]),
    );
  }

  Widget _buildPagination(AppLocalizations t, int page, int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: kCrmBorder))),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text('${t.translate('Page')} ${page + 1} ${t.translate('sur')} $totalPages', style: tInter(fontSize: 12, color: kCrmTextSub)),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 20),
          onPressed: page > 0 ? () => setState(() => _page = page - 1) : null,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, size: 20),
          onPressed: page < totalPages - 1 ? () => setState(() => _page = page + 1) : null,
        ),
      ]),
    );
  }
}

// Date réelle de production (jamais la date du jour) — le champ `date` du
// modèle vient de PorPromesh.dateProduction / IndustrialRecord.dateFiche
// (voir productionRecords.dto.js), au format ISO "yyyy-MM-dd" côté API.
// Affichage standardisé "dd/MM/yyyy" — même format que le reste du module
// Production (voir production_records_screen.dart).
String _formatProductionDate(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '—';
  final parsed = DateTime.tryParse(isoDate);
  if (parsed == null) return isoDate;
  return DateFormat('dd/MM/yyyy').format(parsed);
}

// Libellés Diameter/Cell size partagés — utilisés par
// `_SummaryTableCardState._dataRow` (tableau détaillé PROMESH/PROBAR ci-dessus).
String _diameterLabel(AppLocalizations t, String? diametre) {
  return (diametre == null || diametre.isEmpty) ? t.translate('Non renseigné') : '$diametre mm';
}

String _cellSizeLabel(AppLocalizations t, String? tailleMaille) {
  return (tailleMaille == null || tailleMaille.isEmpty) ? t.translate('Non renseigné') : formatCellSize(tailleMaille);
}

// §MODIFICATION — RÉCAPITULATIF PAR MACHINE : LOGIQUE PARTAGÉE UI/EXPORT
// (2026-09-10) — `MachineDiameterGroup`/`MachineSection`/`aggregateByMachine`
// ont été DÉPLACÉS vers production_summary_model.dart (déjà importé
// ci-dessus) pour être réutilisés TELS QUELS par
// production_summary_export_service.dart (feuille Excel "Récapitulatif
// PROMESH/PROBAR") — jamais une seconde implémentation parallèle qui
// risquerait de désynchroniser les chiffres UI/Excel. Logique de
// regroupement INCHANGÉE par ce déplacement.
