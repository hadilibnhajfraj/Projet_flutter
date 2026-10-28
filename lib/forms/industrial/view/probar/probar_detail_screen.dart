// lib/forms/industrial/view/probar/probar_detail_screen.dart
//
// Détail (lecture seule) d'une fiche de production PROBAR — même mise en
// page que PROMESH (forms/industrial/view/detail/fiche_detail_layout.dart) :
// en-tête avec actions, bannière de verrouillage, barre de résumé, panneaux
// Informations générales / Production / Contrôle qualité, onglets.
// Le contenu propre à PROBAR est décodé une seule fois par ProbarDetailData
// et affiché dans les onglets sous forme compacte (grilles de valeurs,
// tableaux) — mêmes champs, libellés, unités et couleurs que les cartes
// existantes (MachineControlCard.fields, probarValueColor). Quantités en mètres
// linéaires (ml), unité enregistrée, sans conversion. Mêmes actions qu'avant
// (Modifier, Imprimer, Export PDF, Export Excel, Supprimer) et mêmes règles :
// fiche validée (et non refusée) verrouillée.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/route/my_route.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/view/detail/fiche_detail_layout.dart';
import 'package:dash_master_toolkit/forms/industrial/view/poste_dashboard_layout.dart' show pdT, pdPosteLabel, kPosteAccepted, kPosteRejected, kPostePending;
import 'package:dash_master_toolkit/forms/industrial/view/probar/probar_poste_dashboard_screen.dart' show probarFicheNumero;
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import 'package:dash_master_toolkit/forms/production_fiche_approval/fiche_approval_record.dart';
import 'package:dash_master_toolkit/forms/production_fiche_approval/fiche_approval_service.dart';
import 'package:dash_master_toolkit/forms/production_fiche_approval/fiche_approval_widgets.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';
import '../../controller/probar_controller.dart';
import '../../model/industrial_record_model.dart';
import '../../service/industrial_record_service.dart';

import 'widgets/probar_detail_data.dart';
import 'widgets/machine_control_card.dart' show MachineControlCard;
import 'widgets/probar_value_chip.dart' show probarValueColor;

class ProbarDetailScreen extends StatefulWidget {
  final String machine;
  final String poste;
  final String id;

  const ProbarDetailScreen({super.key, required this.machine, required this.poste, required this.id});

  @override
  State<ProbarDetailScreen> createState() => _ProbarDetailScreenState();
}

class _ProbarDetailScreenState extends State<ProbarDetailScreen> {
  bool _loading = true;
  bool _deleting = false;
  String? _error;
  IndustrialRecordModel? _record;
  ProbarDetailData? _data;
  List<FicheApprovalStep> _approvalHistory = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await IndustrialRecordService.instance.fetchById(widget.id);
      if (!mounted) return;
      setState(() {
        _record = r;
        _data = ProbarDetailData.fromModel(r);
      });
      _loadApprovalHistory(r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Historique de validation (API existante, comptes autorisés uniquement).
  Future<void> _loadApprovalHistory(IndustrialRecordModel r) async {
    if (r.approval == null || r.id == null || !AuthService().canViewFicheApprovals) return;
    try {
      final detail = await FicheApprovalService.instance.detail('probar', r.id!);
      if (mounted) setState(() => _approvalHistory = detail.history);
    } catch (e) {
      debugPrint('[ProbarDetail] historique de validation indisponible : $e');
    }
  }

  String get _backRoute =>
      '${MyRoute.productionProbarRoot}/machine/${widget.machine}/poste/${widget.poste}/dashboard';
  String get _modulesRoute =>
      '${MyRoute.productionProbarRoot}/machine/${widget.machine}/poste/${widget.poste}/modules';

  Future<void> _openForEdit() async {
    final c = Get.isRegistered<ProbarController>()
        ? Get.find<ProbarController>()
        : Get.put(ProbarController(), permanent: true);
    await c.bootstrapWithId(widget.machine, widget.poste, widget.id);
    if (mounted) context.go('$_modulesRoute?ficheId=${widget.id}');
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(AppLocalizations.of(ctx).translate('Supprimer la fiche ?')),
        content: Text(AppLocalizations.of(ctx).translate('Cette action est irréversible. La fiche sera définitivement supprimée.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(ctx).translate('Annuler'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kCrmDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(ctx).translate('Supprimer')),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _deleting = true);
    try {
      await IndustrialRecordService.instance.delete(widget.id);
      if (mounted) context.go(_backRoute);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).translate('Erreur')} : $e'), backgroundColor: kCrmDanger));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  // Exports PROBAR : non encore disponibles (comportement existant conservé).
  void _print() => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).translate('Impression — fonctionnalité à venir')), duration: const Duration(seconds: 2)));

  void _exportPdf() => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).translate('Export PDF — fonctionnalité à venir')), duration: const Duration(seconds: 2)));

  void _exportExcel() => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).translate('Export Excel — fonctionnalité à venir')), duration: const Duration(seconds: 2)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final record = _record;
    final data = _data;
    if (_loading && record == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && record == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${pdT(context, 'Erreur de chargement')} : $_error', textAlign: TextAlign.center, style: tInter(fontSize: 13, color: kCrmDanger)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(onPressed: () => context.go(_backRoute), icon: const Icon(Icons.arrow_back_rounded, size: 16), label: Text(pdT(context, 'Retour'))),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 16), label: Text(pdT(context, 'Réessayer'))),
          ]),
        ]),
      );
    }
    if (record == null || data == null) return const SizedBox.shrink();

    // Fiche refusée par le responsable : modifiable pour correction.
    final approval = record.approval;
    final isLocked = record.statut == 'validee' && !(approval?.isRejected ?? false);
    final status = ficheStatus(isDraft: record.statut != 'validee', approvalStatus: approval?.status);
    final lockReason = approval?.isApproved ?? false
        ? 'Cette fiche est verrouillée : elle a été acceptée par le responsable et ne peut plus être modifiée ni supprimée.'
        : 'Cette fiche est verrouillée : sa saisie est terminée, elle ne peut plus être modifiée ni supprimée.';
    final machine = record.machine ?? widget.machine;
    final poste = record.poste ?? widget.poste;
    final heures = fdHours(data.heureDebut, data.heureFin);
    final line = ((int.tryParse(machine) ?? 1) - 1).clamp(0, 3) + 1; // Machine n → mesures Ln
    String mesure(String key, [String unit = '']) => fdMeasure(data.qualiteMesures[key], unit);
    // Mesures qualité de la ligne de cette machine (Machine n → Ln), mêmes
    // champs et unités que l'écran de saisie.
    final hasMesures = ['l${line}h', 'l${line}l', 'l${line}m', 'l${line}d', 'tp'].any((k) => (data.qualiteMesures[k] ?? '').trim().isNotEmpty);
    final machineValues = <(String, String, Color?)>[
      for (final f in MachineControlCard.fields)
        if ((data.machineControl[f.$1] ?? '').trim().isNotEmpty) (f.$2, data.machineControl[f.$1]!.trim(), probarValueColor(data.machineControl[f.$1]!)),
    ];
    final people = <(String, String, Color?)>[
      for (final r in kFichePersonnelRoles)
        if ((data.personnel[r.$1] ?? '').trim().isNotEmpty) (r.$2, data.personnel[r.$1]!.trim(), null),
    ];
    final justification = (data.machineControl['justification'] ?? '').trim();
    // Créneaux de contrôle qualité réellement saisis (un créneau ne contenant
    // que son heure prévue n'est pas un contrôle).
    const cqFields = ['nbBobines', 'vitesse', 'mesure', 'diametre', 'poids', 'longueurBarre', 'longueurDechet'];
    final cq = [
      for (final r in data.controlesQualite)
        if (r['statutCOQ'] != null || cqFields.any((k) => (r[k]?.toString().trim() ?? '').isNotEmpty)) r,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kIndustrialMaxContentWidth),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FicheDetailHeader(
              title: 'Fiche de production PROBAR',
              color: kProbarColor,
              badges: [
                if (isLocked) const FicheBadge(label: 'Verrouillée', color: kFicheLocked, icon: Icons.lock_rounded),
              ],
              onBack: () => context.go(_backRoute),
              actions: [
                FicheAction('edit', label: 'Modifier', icon: Icons.edit_outlined, color: kCrmInfo, onTap: isLocked ? null : _openForEdit, disabledReason: 'Fiche verrouillée'),
                FicheAction('print', label: 'Imprimer', icon: Icons.print_outlined, color: kCrmText, onTap: _print),
                FicheAction('pdf', label: 'Export PDF', icon: Icons.picture_as_pdf_outlined, color: kCrmSecondary, onTap: _exportPdf),
                FicheAction('excel', label: 'Export Excel', icon: Icons.grid_on_rounded, color: kCrmSuccess, onTap: _exportExcel),
                FicheAction('delete', label: 'Supprimer', icon: Icons.delete_outline_rounded, color: kCrmDanger, onTap: (isLocked || _deleting) ? null : _delete, disabledReason: 'Fiche verrouillée'),
              ],
            ),
            if (isLocked) FicheLockBanner(lockReason),
            if (approval != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FicheApprovalNotice(
                  approval: approval,
                  action: approval.isRejected && AuthService().isFicheApprovalCreator && record.id != null
                      ? FicheResubmitButton(ficheType: 'probar', ficheId: record.id!, onResubmitted: (_) => _load())
                      : null,
                ),
              ),
            FicheSummaryBar(items: [
              FicheSummaryItem(Icons.confirmation_number_outlined, 'Numéro de fiche', probarFicheNumero(record), color: kProbarColor),
              FicheSummaryItem(status.icon, 'Statut', pdT(context, status.label), color: status.color),
              FicheSummaryItem(Icons.event_outlined, 'Date de production', fdDate(record.dateFiche)),
              FicheSummaryItem(Icons.schedule_outlined, 'Heure de production', heures),
              FicheSummaryItem(Icons.precision_manufacturing_outlined, 'Machine', '${pdT(context, 'Machine')} $machine'),
              FicheSummaryItem(poste == 'matin' ? Icons.wb_sunny_outlined : Icons.nightlight_outlined, 'Poste', pdT(context, pdPosteLabel(poste))),
            ]),
            FicheRow(children: [
              FichePanel(
                panelKey: 'info',
                icon: Icons.info_outline_rounded,
                title: 'Informations générales',
                color: kProbarColor,
                child: FicheInfoGrid(entries: [
                  ('Numéro de fiche', probarFicheNumero(record)),
                  ('Statut', pdT(context, status.label)),
                  ('Machine', '${pdT(context, 'Machine')} $machine'),
                  ('Poste', pdT(context, pdPosteLabel(poste))),
                  ('Date de production', fdDate(record.dateFiche)),
                  ('Heure de production', heures),
                  ('Opérateur', fdValue(record.operateur)),
                  ('Responsable', fdValue(data.personnel['responsable1'])),
                  ('Producteur (compte)', fdValue(record.creator?['email'])),
                  ('Date de création', fdDateTime(record.createdAt)),
                  ('Dernière modification', fdDateTime(record.updatedAt)),
                  if (approval?.decidedByEmail != null) ('Validateur', approval!.decidedByEmail!),
                  if (approval?.decidedAt != null) ('Date de décision', faDateTime(approval!.decidedAt)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                FicheProductionPanel(
                  color: kProbarColor,
                  label: 'Quantité produite',
                  quantity: record.quantiteProduite,
                  unit: 'ml',
                  // Module Rendement : diamètre en mm (seule autre mesure saisie).
                  extras: [if ((data.diametre ?? '').trim().isNotEmpty) ('Diamètre', fdMeasure(data.diametre, ' mm'))],
                ),
                const SizedBox(height: 12),
                FicheQualityPanel(
                  globalConforme: record.statutQualite == null ? null : record.statutQualite != 'nok',
                  conformes: cq.where((r) => r['statutCOQ'] == 'OK').length,
                  aVerifier: cq.where((r) => r['statutCOQ'] != 'OK' && r['statutCOQ'] != 'NOK').length,
                  nonConformes: cq.where((r) => r['statutCOQ'] == 'NOK').length,
                  note: cq.isEmpty ? null : 'Contrôles qualité par créneau ; « À vérifier » : créneau saisi sans statut.',
                ),
              ]),
            ]),
            FicheDetailTabs(color: kProbarColor, tabs: [
              FicheTab('parameters', label: 'Paramètres de production', icon: Icons.tune_rounded, builder: () => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const FicheSubheading('Contrôle machine', icon: Icons.precision_manufacturing_outlined),
                    if (machineValues.isEmpty)
                      const FicheEmpty('Aucune donnée de contrôle machine enregistrée.', icon: Icons.precision_manufacturing_outlined)
                    else
                      FicheValueGrid(values: machineValues),
                    if (justification.isNotEmpty) FicheNote(label: 'Justification', text: justification, color: kPostePending),
                    const SizedBox(height: 14),
                    const FicheSubheading('Personnel', icon: Icons.groups_2_outlined),
                    if (people.isEmpty) const FicheEmpty('Aucun personnel renseigné', icon: Icons.groups_2_outlined) else FicheValueGrid(values: people),
                  ])),
              FicheTab('quality', label: 'Contrôle qualité', icon: Icons.verified_user_outlined, count: cq.length, builder: () => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const FicheSubheading('Conformité du poste', icon: Icons.fact_check_outlined),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: record.statutQualite == null
                          ? Text(pdT(context, 'Statut non renseigné'), style: tInter(fontSize: 12.5, color: kCrmTextSub))
                          : FicheBadge(
                              label: record.statutQualite == 'nok' ? 'Non conforme' : 'Conforme',
                              color: record.statutQualite == 'nok' ? kPosteRejected : kPosteAccepted,
                              icon: record.statutQualite == 'nok' ? Icons.cancel_rounded : Icons.check_circle_rounded,
                            ),
                    ),
                    if (record.statutQualite == 'nok') ...[
                      FicheNote(label: 'Description', text: fdValue(data.descriptionNonConformite), color: kPosteRejected),
                      FicheNote(label: 'Actions correctives', text: fdValue(data.actionsCorrectives), color: kPosteRejected),
                    ],
                    const SizedBox(height: 14),
                    // Mêmes libellés que l'écran de saisie (probar_controle_qualite_screen).
                    const FicheSubheading('Contrôle qualité par créneau', icon: Icons.fact_check_outlined),
                    FicheTable(
                      tableKey: 'probar-cq',
                      minWidth: 980,
                      columns: const [('Heure', 2), ('Statut', 3), ('Nombre de bobines', 2), ('Vitesse machine', 2), ('Mesure (m/min)', 2), ('Diamètre', 2), ('Poids 1 mètre', 2), ('Longueur de barre', 2), ('Longueur de déchet', 2)],
                      rows: [
                        for (final r in cq)
                          [
                            FicheTable.text(fdTime(r['heure']?.toString()).isEmpty ? '—' : fdTime(r['heure']?.toString()), strong: true),
                            ficheMeasureStatus(switch (r['statutCOQ']) { 'OK' => 'C', 'NOK' => 'NC', _ => null }),
                            for (final k in cqFields) FicheTable.text(fdMeasure(r[k])),
                          ],
                      ],
                      emptyMessage: 'Aucun contrôle qualité saisi sur cette fiche',
                    ),
                    const SizedBox(height: 14),
                    const FicheSubheading('Mesures qualité', icon: Icons.straighten_rounded),
                    FicheTable(
                      tableKey: 'probar-measures',
                      columns: const [('Ligne', 2), ('Heure', 2), ('Longueur', 3), ('Grammage', 3), ('Diamètre', 3), ('Température produit', 3)],
                      rows: [
                        if (hasMesures)
                          [
                            FicheTable.text('L$line', strong: true),
                            FicheTable.text(fdTime(data.qualiteMesures['l${line}h']).isEmpty ? '—' : fdTime(data.qualiteMesures['l${line}h'])),
                            FicheTable.text(mesure('l${line}l', ' mm')),
                            FicheTable.text(mesure('l${line}m', ' g/m²')),
                            FicheTable.text(mesure('l${line}d', ' mm')),
                            FicheTable.text(mesure('tp', ' °C')),
                          ],
                      ],
                      emptyMessage: 'Aucune mesure qualité enregistrée pour cette machine',
                    ),
                  ])),
              FicheTab('materials', label: 'Matières premières', icon: Icons.inventory_2_outlined, builder: () => const FicheEmpty("La fiche PROBAR n'enregistre pas de consommation de matières premières", icon: Icons.inventory_2_outlined)),
              FicheTab('documents', label: 'Documents', icon: Icons.attach_file_rounded, builder: () => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const FicheSubheading('Observation', icon: Icons.chat_bubble_outline_rounded),
                    data.observationsText.trim().isEmpty
                        ? Text(pdT(context, 'Aucune observation.'), style: tInter(fontSize: 12.5, color: kCrmTextSub))
                        : FicheNote(label: 'Observation', text: data.observationsText.trim()),
                    const SizedBox(height: 14),
                    const FicheSubheading('Pièces jointes et photos', icon: Icons.attach_file_rounded),
                    const FicheEmpty('Aucun document joint', icon: Icons.attach_file_rounded),
                  ])),
              FicheTab('history', label: 'Historique', icon: Icons.history_rounded, builder: () => FicheHistoryTimeline(entries: _history(record))),
            ]),
          ]),
        ),
      ),
    );
  }

  List<FicheHistoryEntry> _history(IndustrialRecordModel r) {
    final creator = (r.creator?['email']?.trim().isNotEmpty ?? false) ? r.creator!['email']! : fdValue(r.createdBy);
    final out = <FicheHistoryEntry>[
      FicheHistoryEntry(icon: Icons.add_circle_outline_rounded, color: kProbarColor, title: 'Fiche créée', detail: creator, when: fdDateTime(r.createdAt)),
      if ((r.updatedAt ?? '').isNotEmpty && r.updatedAt != r.createdAt)
        FicheHistoryEntry(icon: Icons.edit_calendar_outlined, color: kCrmTextSub, title: 'Dernière modification', when: fdDateTime(r.updatedAt)),
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
    } else if (r.approval != null) {
      final a = r.approval!;
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
