// lib/production_records/view/production_summary_table_card.dart
//
// Tableau détaillé d'un récapitulatif de production (PROMESH ou PROBAR) :
// lignes paginées à l'affichage (15 / 50 / 100 par page), récapitulatif par
// machine et totaux calculés sur TOUTES les fiches de la période.
// Extrait de production_summary_screen.dart (qui importe l'export Excel, donc
// dart:html) pour pouvoir être testé directement.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../model/production_record_model.dart';
import '../model/production_summary_model.dart';
import 'mesh_size_display.dart';

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
class ProductionSummaryTableCard extends StatefulWidget {
  final Color color;
  final ProductionSummaryTable table;
  final bool isPromesh;
  final String grandTotalLabelKey;
  final ProductionRowSort? sort;
  final ValueChanged<ProductionRowSort?> onSortChanged;

  const ProductionSummaryTableCard({
    super.key,
    required this.color,
    required this.table,
    required this.isPromesh,
    required this.grandTotalLabelKey,
    required this.sort,
    required this.onSortChanged,
  });

  @override
  State<ProductionSummaryTableCard> createState() => _ProductionSummaryTableCardState();
}

class _ProductionSummaryTableCardState extends State<ProductionSummaryTableCard> {
  // Lignes par page : 15 (défaut) / 50 / 100 — choisi par l'utilisateur. La
  // pagination est faite à l'affichage : le backend renvoie TOUTES les fiches
  // de la période (totaux, récapitulatif et exports portent sur l'ensemble).
  int _rowsPerPage = kProductionSummaryPageSizes.first;
  int _page = 0;
  final ScrollController _hScroll = ScrollController();

  // Largeur minimale d'une unité de `flex` : en dessous, les colonnes se
  // chevauchent (zoom du navigateur, fenêtre étroite) — le tableau garde
  // alors cette largeur et défile horizontalement, sans réduire le texte.
  static const _minFlexUnit = 46.0;
  static const _hPadding = 18.0;

  int get _flexSum => _flexIndex + _flexDate + _flexMachine + _flexShift + _flexDiameter + (widget.isPromesh ? _flexMesh : 0) + _flexQty + _flexWaste;
  double get _minTableWidth => _flexSum * _minFlexUnit + 2 * _hPadding;

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

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

  // §MODIFICATION — EXCLUSION "NOT SPECIFIED" DE "PROMESH PRODUCTION"
  // (2026-09-22/23, tickets "supprimer complètement l'affichage des lignes
  // Not specified" puis "supprimer les lignes incomplètes/orphelines" —
  // cette dernière RESSERRE la règle : Machine et Shift comptent désormais
  // AUSSI, pas seulement Diameter+Cell size, voir `isValidProductionRecord`
  // dans production_summary_model.dart) — SOURCE UNIQUE réutilisée par
  // `build()` (lignes/pagination/tri), `_machineBreakdownBlock`
  // (récapitulatif), `_recapWasteTotal`/`_recapQuantityTotal` (totaux) :
  // "Production Records → filtrer → PROMESH Production → Récapitulatif →
  // sous-totaux → totaux", jamais un filtrage différent à chaque étage.
  // PROBAR (jamais concerné par aucun de ces tickets — pas de Cell size)
  // garde `widget.table.rows` intégral, inchangé.
  List<ProductionRecordModel> get _validRows =>
      widget.isPromesh ? widget.table.rows.where(isValidProductionRecord).toList() : widget.table.rows;

  @override
  void didUpdateWidget(covariant ProductionSummaryTableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Filtres changés → les fiches affichées ne correspondent plus forcément
    // à la page courante ; on revient toujours en page 1 pour éviter une
    // page vide.
    if (oldWidget.table.rows != widget.table.rows) _page = 0;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final rows = _validRows;
    // §MODIFICATION — TRI DES TABLEAUX "PROMESH/PROBAR PRODUCTION"
    // (2026-09-11) — `displayRows` est la SEULE variable affectée par le tri
    // (§13/§14 du ticket : appliqué APRÈS les filtres déjà pris en compte
    // par `rows`, et AVANT la pagination ci-dessous — jamais un tri limité à
    // la page courante). `rows` (non trié) reste utilisé TEL QUEL par
    // `_machineBreakdownBlock`/`_grandTotalRow`/`_grandTotalWasteRow`
    // ci-dessous : le tri d'affichage ne modifie jamais le récapitulatif ni
    // les totaux (§15).
    final displayRows = sortProductionRows(rows, column: widget.sort?.column, ascending: widget.sort?.ascending ?? true);
    final window = ProductionPageWindow.of(total: displayRows.length, pageSize: _rowsPerPage, page: _page);
    final pageRows = displayRows.sublist(window.start, window.end);

    return Container(
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCrmBorder)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (rows.isNotEmpty) _buildToolbar(t, window),
        if (widget.table.truncated) _buildTruncatedNotice(t),
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
            // Jamais plus étroit que la largeur minimale lisible : au-delà, un
            // défilement horizontal (barre visible) plutôt que des colonnes
            // coupées ou superposées. En-tête, lignes et totaux partagent
            // cette même largeur : ils restent alignés.
            final minWidth = _minTableWidth;
            final tableWidth = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
            final scrolls = tableWidth > constraints.maxWidth;
            return Scrollbar(
              controller: _hScroll,
              thumbVisibility: scrolls,
              child: SingleChildScrollView(
              key: const ValueKey('production-summary-hscroll'),
              controller: _hScroll,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(bottom: scrolls ? 10 : 0),
              child: SizedBox(
                width: tableWidth,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _headerRow(t),
                  for (int i = 0; i < pageRows.length; i++) _dataRow(t, window.start + i + 1, pageRows[i]),
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
              ),
            );
          }),
        if (rows.isNotEmpty) _buildPagination(t, window),
      ]),
    );
  }

  Widget _headerRow(AppLocalizations t) {
    return Container(
      color: kCrmBg,
      padding: const EdgeInsets.symmetric(horizontal: _hPadding, vertical: 10),
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
        Expanded(flex: _flexIndex, child: _cell('$index', textStyle)),
        Expanded(flex: _flexDate, child: _cell(dateLabel, textStyle)),
        Expanded(
          flex: _flexMachine,
          child: isPromesh4 ? Align(alignment: Alignment.centerLeft, child: _promesh4Badge(r.machine)) : _cell(machineLabel, textStyle),
        ),
        Expanded(flex: _flexShift, child: _shiftBadge(r.poste)),
        Expanded(flex: _flexDiameter, child: _cell(diameterLabel, textStyle)),
        if (widget.isPromesh) Expanded(flex: _flexMesh, child: _cell(meshLabel, textStyle)),
        Expanded(flex: _flexQty, child: _cell(qtyLabel, textStyle, alignRight: true)),
        Expanded(flex: _flexWaste, child: _cell(wasteLabel, textStyle, alignRight: true)),
      ]),
    );
  }

  /// Cellule de texte : une seule ligne, coupée proprement (« … ») si elle ne
  /// tient pas — avec une marge à droite pour ne jamais toucher la colonne
  /// suivante. La valeur complète reste lisible au survol.
  Widget _cell(String text, TextStyle style, {bool alignRight = false}) {
    return Padding(
      padding: EdgeInsets.only(right: alignRight ? 0 : 8, left: alignRight ? 8 : 0),
      child: Tooltip(
        message: text,
        waitDuration: const Duration(milliseconds: 600),
        child: Text(text, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, textAlign: alignRight ? TextAlign.right : TextAlign.left, style: style),
      ),
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
          maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
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
  // §CORRECTION — EXCLUSION DES LIGNES "NOT SPECIFIED" (2026-09-21/22,
  // tickets "corriger l'affichage du Production Summary") — `_validRows`
  // (getter partagé, voir plus haut) retire RÉELLEMENT (jamais un masquage
  // visuel) toute fiche dont Diameter OU Cell size est absent/vide AVANT
  // tout regroupement (§1/§4/§9 du ticket) — désormais la MÊME liste que
  // celle affichée dans le tableau détaillé "PROMESH Production" au-dessus
  // (§6/§10 du dernier ticket : une seule source de vérité, du tableau
  // jusqu'aux totaux).
  Widget _machineBreakdownBlock(AppLocalizations t) {
    final validRows = _validRows;
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
    final validRows = _validRows;
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
    // `_validRows` (getter partagé) que `_machineBreakdownBlock` (§2/§7 du
    // ticket : "Not specified" ne doit avoir AUCUN impact sur le total),
    // pour que ce total reste la somme exacte des sous-totaux réellement
    // affichés.
    final validRows = _validRows;
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

  void _setRowsPerPage(int value) {
    if (value == _rowsPerPage) return;
    // Nouvelle taille de page : retour à la première page (jamais une page vide).
    setState(() {
      _rowsPerPage = value;
      _page = 0;
    });
  }

  /// Au-dessus du tableau : nombre total de résultats + « Lignes par page ».
  Widget _buildToolbar(AppLocalizations t, ProductionPageWindow window) {
    final total = window.total;
    return Container(
      padding: const EdgeInsets.fromLTRB(_hPadding, 10, 12, 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
      child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 16, runSpacing: 8, children: [
        Text(
          '$total ${t.translate(total > 1 ? 'résultats' : 'résultat')}',
          key: const ValueKey('production-summary-total'),
          style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText),
        ),
        // Très étroit (fort zoom) : réduit d'un bloc plutôt que de déborder.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${t.translate('Lignes par page')} :', style: tInter(fontSize: 12, color: kCrmTextSub)),
          const SizedBox(width: 8),
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: kCrmBorder)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                key: const ValueKey('production-summary-page-size'),
                value: _rowsPerPage,
                isDense: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: kCrmTextSub),
                style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText),
                items: [
                  for (final size in kProductionSummaryPageSizes) DropdownMenuItem<int>(value: size, child: Text('$size')),
                ],
                onChanged: (v) => v == null ? null : _setRowsPerPage(v),
              ),
            ),
          ),
        ]),
        ),
      ]),
    );
  }

  /// Le backend a atteint son plafond de lecture : toutes les fiches de la
  /// période ne sont pas chargées — dit clairement, jamais silencieux.
  Widget _buildTruncatedNotice(AppLocalizations t) {
    return Container(
      key: const ValueKey('production-summary-truncated'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: _hPadding, vertical: 9),
      color: const Color(0xFFFEF3C7),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFFB45309)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${t.translate('Période trop large : affichage limité aux')} ${widget.table.rows.length} ${t.translate('fiches les plus récentes sur')} ${widget.table.totalMatching}. ${t.translate('Réduisez la période pour consulter toutes les fiches.')}',
            style: tInter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
          ),
        ),
      ]),
    );
  }

  /// Sous le tableau : lignes affichées, page actuelle, navigation.
  Widget _buildPagination(AppLocalizations t, ProductionPageWindow window) {
    void go(int page) => setState(() => _page = page);
    Widget nav(String key, IconData icon, String tooltipKey, VoidCallback? onPressed) => IconButton(
          key: ValueKey('production-summary-$key'),
          tooltip: t.translate(tooltipKey),
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, size: 20),
          onPressed: onPressed,
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(_hPadding, 8, 8, 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: kCrmBorder))),
      child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 16, runSpacing: 4, children: [
        Text(
          '${t.translate('Lignes')} ${window.start + 1}–${window.end} ${t.translate('sur')} ${window.total}',
          key: const ValueKey('production-summary-range'),
          style: tInter(fontSize: 12, color: kCrmTextSub),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
          nav('first', Icons.first_page_rounded, 'Première page', window.hasPrevious ? () => go(0) : null),
          nav('previous', Icons.chevron_left_rounded, 'Page précédente', window.hasPrevious ? () => go(window.page - 1) : null),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('${t.translate('Page')} ${window.page + 1} ${t.translate('sur')} ${window.totalPages}',
                key: const ValueKey('production-summary-page'), style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kCrmText)),
          ),
          nav('next', Icons.chevron_right_rounded, 'Page suivante', window.hasNext ? () => go(window.page + 1) : null),
          nav('last', Icons.last_page_rounded, 'Dernière page', window.hasNext ? () => go(window.totalPages - 1) : null),
        ]),
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
// `_ProductionSummaryTableCardState._dataRow` (tableau détaillé PROMESH/PROBAR ci-dessus).
String _diameterLabel(AppLocalizations t, String? diametre) {
  return (diametre == null || diametre.isEmpty) ? t.translate('Non renseigné') : '$diametre mm';
}

String _cellSizeLabel(AppLocalizations t, String? tailleMaille) {
  // Présentation uniquement : « 20x20 », « 20X20 », « 20*20 »… → « 20 X 20 ».
  return (tailleMaille == null || tailleMaille.isEmpty) ? t.translate('Non renseigné') : formatMeshSizeForDisplay(tailleMaille);
}

// §MODIFICATION — RÉCAPITULATIF PAR MACHINE : LOGIQUE PARTAGÉE UI/EXPORT
// (2026-09-10) — `MachineDiameterGroup`/`MachineSection`/`aggregateByMachine`
// ont été DÉPLACÉS vers production_summary_model.dart (déjà importé
// ci-dessus) pour être réutilisés TELS QUELS par
// production_summary_export_service.dart (feuille Excel "Récapitulatif
// PROMESH/PROBAR") — jamais une seconde implémentation parallèle qui
// risquerait de désynchroniser les chiffres UI/Excel. Logique de
// regroupement INCHANGÉE par ce déplacement.
