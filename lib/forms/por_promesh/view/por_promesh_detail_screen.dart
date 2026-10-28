// lib/forms/por_promesh/view/por_promesh_detail_screen.dart
//
// Détail (lecture seule) d'une fiche de production PROMESH. Mise en page
// commune avec PROBAR (forms/industrial/view/detail/fiche_detail_layout.dart) :
// en-tête (numéro, statut, date, heure, machine, poste, actions), bannière
// de verrouillage, barre de résumé, panneaux Informations générales /
// Production / Contrôle qualité, puis onglets Paramètres de production,
// Contrôle qualité, Matières premières, Documents, Historique.
//
// Mêmes données qu'avant (`PorPromeshModel`, chargé UNE SEULE FOIS par
// `_load()`), mêmes actions (Modifier, Imprimer, Export PDF, Export Excel,
// Supprimer — désactivées sur une fiche verrouillée), même resoumission d'une
// fiche refusée. Aucune route, aucun modèle, aucun service ni API modifié.
// Seul ajout de lecture : l'historique de validation (GET
// /production-fiche-approvals/:type/:id, API existante) pour les comptes qui
// y ont accès — sinon l'historique se limite aux dates de la fiche.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/route/my_route.dart';
import 'package:dash_master_toolkit/providers/api_client.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/view/detail/fiche_detail_layout.dart';
import 'package:dash_master_toolkit/forms/industrial/view/poste_dashboard_layout.dart' show pdT, pdPosteLabel, kPosteAccepted, kPosteRejected, kPostePending;

import 'package:dash_master_toolkit/forms/production_fiche_approval/fiche_approval_record.dart';
import 'package:dash_master_toolkit/forms/production_fiche_approval/fiche_approval_service.dart';
import 'package:dash_master_toolkit/forms/production_fiche_approval/fiche_approval_widgets.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';
import '../model/por_promesh_model.dart';
import '../service/por_promesh_service.dart';
import '../service/por_promesh_pdf_service.dart';
import '../service/por_promesh_excel_service.dart';
import 'detail/detail_machine_value_card.dart';

const _imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];

class PorPromeshDetailScreen extends StatefulWidget {
  final String id;
  const PorPromeshDetailScreen({super.key, required this.id});

  @override
  State<PorPromeshDetailScreen> createState() => _PorPromeshDetailScreenState();
}

class _PorPromeshDetailScreenState extends State<PorPromeshDetailScreen> {
  bool _loading = true;
  String? _error;
  PorPromeshModel? _item;
  List<FicheApprovalStep> _approvalHistory = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Un seul appel réseau pour la fiche — toutes les sections lisent ensuite
  // `_item` (même instance mémoire, jamais re-fetché par section).
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final item = await PorPromeshService.instance.fetchById(widget.id);
      if (!mounted) return;
      setState(() => _item = item);
      _loadApprovalHistory(item);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Historique de validation (lecture seule, comptes autorisés uniquement ;
  // indisponible → l'historique de la fiche reste affiché sans lui).
  Future<void> _loadApprovalHistory(PorPromeshModel item) async {
    if (item.approval == null || item.id == null || !AuthService().canViewFicheApprovals) return;
    try {
      final detail = await FicheApprovalService.instance.detail('promesh', item.id!);
      if (mounted) setState(() => _approvalHistory = detail.history);
    } catch (e) {
      debugPrint('[PorPromeshDetail] historique de validation indisponible : $e');
    }
  }

  Future<void> _delete() async {
    final item = _item;
    if (item?.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Supprimer'),
        content: const Text('Voulez-vous vraiment supprimer cette fiche POR PROMESH ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await PorPromeshService.instance.delete(item!.id!);
      if (!mounted) return;
      context.go(MyRoute.porPromeshListScreen);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red.shade700));
    }
  }

  // Modifier une fiche rouvre le même parcours Machine→Poste→Modules que
  // les opérateurs (aucun formulaire CRM dédié).
  String _editRoute(PorPromeshModel item) {
    if (item.machine == null || item.poste == null) return MyRoute.productionPromeshRoot;
    // §CORRECTION ÉDITION PROMESH (2026-09-30) : ouvrait "Informations
    // générales" SANS id → la fiche était recherchée par machine/poste/date
    // du JOUR (autre fiche chargée, ou formulaire vide puis CRÉATION d'un
    // doublon à l'enregistrement). On ouvre désormais la fiche par son id.
    return '${MyRoute.productionPromeshRoot}/machine/${item.machine}/poste/${item.poste}/modules?ficheId=${item.id}';
  }

  Future<void> _printPdf() async {
    if (_item == null) return;
    try {
      await PorPromeshPdfService.instance.printPdf(_item!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur impression : $e'), backgroundColor: Colors.red.shade700));
    }
  }

  Future<void> _exportPdf() async {
    if (_item == null) return;
    try {
      await PorPromeshPdfService.instance.exportPdf(_item!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur export PDF : $e'), backgroundColor: Colors.red.shade700));
    }
  }

  Future<void> _exportExcel() async {
    if (_item == null) return;
    try {
      PorPromeshExcelService.instance.export(_item!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur export Excel : $e'), backgroundColor: Colors.red.shade700));
    }
  }

  void _back() => context.go(MyRoute.porPromeshListScreen);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final m = _item;
    if (_loading && m == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && m == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${pdT(context, 'Erreur de chargement')} : $_error', textAlign: TextAlign.center, style: tInter(fontSize: 13, color: kCrmDanger)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(onPressed: _back, icon: const Icon(Icons.arrow_back_rounded, size: 16), label: Text(pdT(context, 'Retour'))),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 16), label: Text(pdT(context, 'Réessayer'))),
          ]),
        ]),
      );
    }
    if (m == null) return const SizedBox.shrink();

    final status = ficheStatus(isDraft: m.status == 'draft', approvalStatus: m.approval?.status);
    final lockReason = m.approval?.isApproved ?? false
        ? 'Cette fiche est verrouillée : elle a été acceptée par le responsable et ne peut plus être modifiée ni supprimée.'
        : 'Cette fiche est verrouillée : sa saisie est terminée, elle ne peut plus être modifiée ni supprimée.';
    final qc = _qualityCounts(m);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kIndustrialMaxContentWidth),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FicheDetailHeader(
              title: 'Fiche de production PROMESH',
              color: kPromeshColor,
              badges: [
                if (m.isLocked) const FicheBadge(label: 'Verrouillée', color: kFicheLocked, icon: Icons.lock_rounded),
              ],
              onBack: _back,
              actions: [
                FicheAction('edit', label: 'Modifier', icon: Icons.edit_outlined, color: kCrmInfo, onTap: m.isLocked ? null : () => context.go(_editRoute(m)), disabledReason: 'Fiche verrouillée'),
                FicheAction('print', label: 'Imprimer', icon: Icons.print_outlined, color: kCrmText, onTap: _printPdf),
                FicheAction('pdf', label: 'Export PDF', icon: Icons.picture_as_pdf_outlined, color: kCrmSecondary, onTap: _exportPdf),
                FicheAction('excel', label: 'Export Excel', icon: Icons.grid_on_rounded, color: kCrmSuccess, onTap: _exportExcel),
                FicheAction('delete', label: 'Supprimer', icon: Icons.delete_outline_rounded, color: kCrmDanger, onTap: m.isLocked ? null : _delete, disabledReason: 'Fiche verrouillée'),
              ],
            ),
            if (m.isLocked) FicheLockBanner(lockReason),
            if (m.approval != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FicheApprovalNotice(
                  approval: m.approval!,
                  action: m.approval!.isRejected && AuthService().isFicheApprovalCreator && m.id != null
                      ? FicheResubmitButton(ficheType: 'promesh', ficheId: m.id!, onResubmitted: (_) => _load())
                      : null,
                ),
              ),
            FicheSummaryBar(items: [
              FicheSummaryItem(Icons.confirmation_number_outlined, 'Numéro de fiche', fdValue(m.numero), color: kPromeshColor),
              FicheSummaryItem(status.icon, 'Statut', pdT(context, status.label), color: status.color),
              FicheSummaryItem(Icons.event_outlined, 'Date de production', fdDate(m.dateProduction)),
              FicheSummaryItem(Icons.schedule_outlined, 'Heure de production', fdHours(m.heureDebut, m.heureFin)),
              FicheSummaryItem(Icons.precision_manufacturing_outlined, 'Machine', m.machine == null ? '—' : '${pdT(context, 'Machine')} ${m.machine}'),
              FicheSummaryItem(m.poste == 'matin' ? Icons.wb_sunny_outlined : Icons.nightlight_outlined, 'Poste', pdT(context, pdPosteLabel(m.poste))),
            ]),
            FicheRow(children: [
              FichePanel(
                panelKey: 'info',
                icon: Icons.info_outline_rounded,
                title: 'Informations générales',
                color: kPromeshColor,
                child: FicheInfoGrid(entries: [
                  ('Numéro de fiche', fdValue(m.numero)),
                  ('Statut', pdT(context, status.label)),
                  ('Machine', m.machine == null ? '—' : '${pdT(context, 'Machine')} ${m.machine}'),
                  ('Poste', pdT(context, pdPosteLabel(m.poste))),
                  ('Date de production', fdDate(m.dateProduction)),
                  ('Heure de production', fdHours(m.heureDebut, m.heureFin)),
                  ('Opérateur', fdValue(m.operateur)),
                  ('Responsable', fdValue(m.personnelActif['responsable1'])),
                  ('Producteur (compte)', fdValue(m.creator?['email'])),
                  ('Date de création', fdDateTime(m.createdAt)),
                  ('Dernière modification', fdDateTime(m.updatedAt)),
                  if ((m.validatedAt ?? '').isNotEmpty) ('Fin de saisie', fdDateTime(m.validatedAt)),
                  if ((m.dateValidationProcess ?? '').isNotEmpty) ('Date de validation', fdDate(m.dateValidationProcess)),
                  if (m.approval?.decidedByEmail != null) ('Validateur', m.approval!.decidedByEmail!),
                  if (m.approval?.decidedAt != null) ('Date de décision', faDateTime(m.approval!.decidedAt)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                FicheProductionPanel(
                  color: kPromeshColor,
                  label: 'Quantité produite',
                  quantity: m.productionM2,
                  unit: 'm²',
                  extras: [
                    // Champs du module Rendement (unités de saisie : mm).
                    if ((m.diametreMaille2 ?? '').trim().isNotEmpty) ('Diamètre', '${m.diametreMaille2!.trim()} mm'),
                    if ((m.diametreMaille1 ?? '').trim().isNotEmpty) ('Taille de maille', '${m.diametreMaille1!.trim()} mm'),
                    if ((m.diametreMaille3 ?? '').trim().isNotEmpty) ('Maille 3', m.diametreMaille3!.trim()),
                  ],
                ),
                const SizedBox(height: 12),
                FicheQualityPanel(
                  globalConforme: m.conformite == null ? null : m.conformite != 'non_conforme',
                  conformes: qc.$1,
                  aVerifier: qc.$2,
                  nonConformes: qc.$3,
                  note: _filledMeasures(m).isEmpty ? null : 'Mesures du contrôle qualité produit ; « À vérifier » : mesure sans statut.',
                ),
              ]),
            ]),
            FicheDetailTabs(color: kPromeshColor, tabs: [
              FicheTab('parameters', label: 'Paramètres de production', icon: Icons.tune_rounded, builder: () => _parametersTab(m)),
              FicheTab('quality', label: 'Contrôle qualité', icon: Icons.verified_user_outlined, count: _filledMeasures(m).length, builder: () => _qualityTab(m)),
              FicheTab('materials', label: 'Matières premières', icon: Icons.inventory_2_outlined, count: m.consommations.length, builder: () => _materialsTab(m)),
              FicheTab('documents', label: 'Documents', icon: Icons.attach_file_rounded, count: m.attachments.length, builder: () => _documentsTab(m)),
              FicheTab('history', label: 'Historique', icon: Icons.history_rounded, builder: () => FicheHistoryTimeline(entries: _history(m))),
            ]),
          ]),
        ),
      ),
    );
  }

  /// (conformes, sans statut, non conformes) des mesures du contrôle qualité.
  (int, int, int) _qualityCounts(PorPromeshModel m) {
    var ok = 0, check = 0, nok = 0;
    for (final r in _filledMeasures(m)) {
      final s = (r['statutCOQ'] ?? r['statut'])?.toString();
      if (s == 'C') {
        ok++;
      } else if (s == 'NC') {
        nok++;
      } else {
        check++;
      }
    }
    return (ok, check, nok);
  }

  /// Mesures réellement saisies (au moins une valeur ou un statut).
  List<Map<String, dynamic>> _filledMeasures(PorPromeshModel m) => [
        for (final r in m.controlesQualite)
          if (['numeroPlaque', 'maille', 'longueur', 'largeur', 'statutCOQ', 'statut'].any((k) => (r[k]?.toString().trim() ?? '').isNotEmpty)) r,
      ];

  // ── Onglet 1 : paramètres de production ─────────────────────────────────

  Widget _parametersTab(PorPromeshModel m) {
    final people = [
      for (final r in kFichePersonnelRoles)
        if ((m.personnelActif[r.$1] ?? '').trim().isNotEmpty) (r.$2, m.personnelActif[r.$1]!.trim(), null as Color?),
    ];
    final justification = (m.justificationControleMachine ?? '').trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const FicheSubheading('Contrôle machine', icon: Icons.precision_manufacturing_outlined),
      FicheValueGrid(values: [
        ('Air', fdValue(m.air), detailAirColor(m.air)),
        ('Niveau Bain Eau', fdValue(m.niveauBainEau), detailNiveauBainEauColor(m.niveauBainEau)),
        ('Température des Pistons', m.temperaturePistons == null ? '—' : '${fdNumber(m.temperaturePistons)} °C', kCrmInfo),
        ('État Pistons', fdValue(m.etatPistons), detailEtatPistonsColor(m.etatPistons)),
        ('Fluide Visuel', fdValue(m.fluideVisuel), detailFluideVisuelColor(m.fluideVisuel)),
      ]),
      if (justification.isNotEmpty) FicheNote(label: 'Justification', text: justification, color: kPostePending),
      const SizedBox(height: 14),
      const FicheSubheading('Personnel', icon: Icons.groups_2_outlined),
      if (people.isEmpty) const FicheEmpty('Aucun personnel renseigné', icon: Icons.groups_2_outlined) else FicheValueGrid(values: people),
      if ((m.observationPersonnel ?? '').trim().isNotEmpty) FicheNote(label: 'Observation personnel', text: m.observationPersonnel!.trim()),
      const SizedBox(height: 14),
      const FicheSubheading('Arrêts machine', icon: Icons.pause_circle_outline_rounded),
      FicheTable(
        tableKey: 'stops',
        columns: const [('Arrêt', 3), ('Observation', 5)],
        rows: [for (final a in m.arretsMachine) [FicheTable.text(fdValue(a['tArret']), strong: true), FicheTable.text(fdValue(a['observationMachine']))]],
        emptyMessage: 'Aucun arrêt machine enregistré',
      ),
    ]);
  }

  // ── Onglet 2 : contrôle qualité ─────────────────────────────────────────

  Widget _qualityTab(PorPromeshModel m) {
    final nonConforme = m.conformite == 'non_conforme';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const FicheSubheading('Conformité du poste', icon: Icons.fact_check_outlined),
      Align(
        alignment: Alignment.centerLeft,
        child: m.conformite == null
            ? Text(pdT(context, 'Statut non renseigné'), style: tInter(fontSize: 12.5, color: kCrmTextSub))
            : FicheBadge(
                label: nonConforme ? 'Non conforme' : 'Conforme',
                color: nonConforme ? kPosteRejected : kPosteAccepted,
                icon: nonConforme ? Icons.cancel_rounded : Icons.check_circle_rounded,
              ),
      ),
      if (nonConforme) ...[
        FicheNote(label: 'Description', text: fdValue(m.descriptionNonConformite), color: kPosteRejected),
        FicheNote(label: 'Actions correctives', text: fdValue(m.actionsCorrectives), color: kPosteRejected),
      ],
      const SizedBox(height: 14),
      const FicheSubheading('Contrôle qualité produit', icon: Icons.straighten_rounded),
      // Mêmes colonnes et mêmes clés que le tableau existant (Heure, N° Plaque,
      // Maille, Longueur, Largeur, Statut C / NC).
      FicheTable(
        tableKey: 'promesh-measures',
        columns: const [('Heure', 2), ('N° Plaque', 3), ('Maille', 2), ('Longueur', 2), ('Largeur', 2), ('Statut', 3)],
        rows: [
          for (final r in _filledMeasures(m))
            [
              FicheTable.text(fdTime(r['heure']?.toString()).isEmpty ? '—' : fdTime(r['heure']?.toString()), strong: true),
              FicheTable.text(fdValue(r['numeroPlaque'])),
              FicheTable.text(fdMeasure(r['maille'])),
              FicheTable.text(fdMeasure(r['longueur'])),
              FicheTable.text(fdMeasure(r['largeur'])),
              ficheMeasureStatus((r['statutCOQ'] ?? r['statut'])?.toString()),
            ],
        ],
        emptyMessage: 'Aucune mesure enregistrée.',
      ),
    ]);
  }

  // ── Onglet 3 : matières premières (consommations de la fiche) ───────────

  Widget _materialsTab(PorPromeshModel m) => FicheTable(
        tableKey: 'materials',
        columns: const [('Désignation article', 5), ('Métrage', 2), ('Observation', 5)],
        rows: [
          for (final c in m.consommations)
            [
              FicheTable.text(fdValue(c['designationArticle']), strong: true),
              FicheTable.text(fdMeasure(c['metrage'])),
              FicheTable.text(fdValue(c['observation'])),
            ],
        ],
        emptyMessage: 'Aucune consommation de matière enregistrée sur cette fiche',
      );

  // ── Onglet 4 : documents et observations ────────────────────────────────

  bool _isImage(String fileUrl) => _imageExtensions.any((ext) => fileUrl.toLowerCase().endsWith(ext));
  String _fullUrl(String fileUrl) => '${ApiClient.instance.dio.options.baseUrl}$fileUrl';

  Widget _attachmentTile(Map<String, dynamic> a) {
    final fileUrl = (a['fileUrl'] ?? '').toString();
    final fileName = (a['fileName'] ?? '').toString();
    return Container(
      width: 120,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: _isImage(fileUrl)
              ? Image.network(_fullUrl(fileUrl),
                  height: 70, width: 100, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 32, color: kCrmTextSub))
              : Container(height: 70, width: 100, color: kCrmSurface, alignment: Alignment.center, child: const Icon(Icons.insert_drive_file_outlined, size: 28, color: kCrmTextSub)),
        ),
        const SizedBox(height: 4),
        Text(fileName.isEmpty ? pdT(context, 'Fichier') : fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 10, color: kCrmTextSub)),
      ]),
    );
  }

  Widget _documentsTab(PorPromeshModel m) {
    final photo = (m.photoNonConformite ?? '').trim();
    final files = [
      ...m.attachments,
      if (photo.isNotEmpty) {'fileUrl': photo, 'fileName': pdT(context, 'Photo non-conformité')},
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const FicheSubheading('Observation', icon: Icons.chat_bubble_outline_rounded),
      (m.observationsGenerales ?? '').trim().isEmpty
          ? Text(pdT(context, 'Aucune observation.'), style: tInter(fontSize: 12.5, color: kCrmTextSub))
          : FicheNote(label: 'Observation responsable production', text: m.observationsGenerales!.trim()),
      const SizedBox(height: 14),
      const FicheSubheading('Pièces jointes et photos', icon: Icons.attach_file_rounded),
      if (files.isEmpty) const FicheEmpty('Aucun document joint', icon: Icons.attach_file_rounded) else Wrap(spacing: 10, runSpacing: 10, children: [for (final a in files) _attachmentTile(a)]),
    ]);
  }

  // ── Onglet 5 : historique ───────────────────────────────────────────────

  List<FicheHistoryEntry> _history(PorPromeshModel m) {
    final creator = (m.creator?['email']?.trim().isNotEmpty ?? false) ? m.creator!['email']! : fdValue(m.createdBy);
    final out = <FicheHistoryEntry>[
      FicheHistoryEntry(icon: Icons.add_circle_outline_rounded, color: kPromeshColor, title: 'Fiche créée', detail: creator, when: fdDateTime(m.createdAt)),
      if ((m.updatedAt ?? '').isNotEmpty && m.updatedAt != m.createdAt)
        FicheHistoryEntry(icon: Icons.edit_calendar_outlined, color: kCrmTextSub, title: 'Dernière modification', when: fdDateTime(m.updatedAt)),
      // Fin de saisie : `validatedAt` (horodatage réel) ; à défaut, la date
      // du visa process si elle a été saisie.
      if ((m.validatedAt ?? '').isNotEmpty)
        FicheHistoryEntry(icon: Icons.task_alt_rounded, color: kFicheSubmitted, title: 'Saisie terminée', when: fdDateTime(m.validatedAt))
      else if ((m.dateValidationProcess ?? '').isNotEmpty)
        FicheHistoryEntry(icon: Icons.task_alt_rounded, color: kFicheSubmitted, title: 'Saisie terminée', when: fdDate(m.dateValidationProcess)),
    ];
    if (_approvalHistory.isNotEmpty) {
      for (final h in _approvalHistory) {
        final s = ficheStatus(isDraft: false, approvalStatus: h.toStatus);
        out.add(FicheHistoryEntry(
          icon: s.icon,
          color: s.color,
          title: '${pdT(context, 'Validation')} : ${pdT(context, s.label)}',
          detail: [if (h.changedByEmail != null) h.changedByEmail!, if ((h.comment ?? '').isNotEmpty) '« ${h.comment} »'].join(' · '),
          when: faDateTime(h.createdAt),
        ));
      }
    } else if (m.approval != null) {
      final a = m.approval!;
      final s = ficheStatus(isDraft: false, approvalStatus: a.status);
      out.add(FicheHistoryEntry(
        icon: s.icon,
        color: s.color,
        title: '${pdT(context, 'Validation')} : ${pdT(context, s.label)}',
        detail: [if (a.decidedByEmail != null) a.decidedByEmail!, if ((a.rejectionComment ?? '').isNotEmpty) '« ${a.rejectionComment} »'].join(' · '),
        when: faDateTime(a.decidedAt ?? a.submittedAt),
      ));
    }
    return out;
  }
}
