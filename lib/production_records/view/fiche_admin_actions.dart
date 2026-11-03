// lib/production_records/view/fiche_admin_actions.dart
//
// « Consultation des fiches de production » — actions Modifier / Supprimer
// du root admin (cbitunisia@cbi-tunisia.com). Le droit vient du backend
// (user.permissions.productionFicheAdmin, compte relu en base) et chaque
// route le revérifie : ces actions ne font qu'afficher ce que le serveur
// autorise. Les écrans de saisie et les services existants sont réutilisés.

import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/forms/industrial/service/industrial_record_service.dart';
import 'package:dash_master_toolkit/forms/por_promesh/service/por_promesh_service.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/production_dashboard/production_dashboard_routes.dart';

import '../model/production_record_model.dart';

/// Ce que l'interface propose au root admin pour une fiche : jamais rien sur
/// une fiche archivée (demande de désarchivage obligatoire, pour tous).
class FicheAdminActions {
  /// Boutons Modifier / Supprimer affichés (root admin uniquement).
  final bool visible;
  final bool canEdit;
  final bool canDelete;
  final String? editRoute;
  final String? blockedReason;
  const FicheAdminActions({this.visible = true, required this.canEdit, required this.canDelete, this.editRoute, this.blockedReason});

  factory FicheAdminActions.of(ProductionRecordModel r, {required bool isFicheAdmin}) {
    if (!isFicheAdmin) return const FicheAdminActions(visible: false, canEdit: false, canDelete: false);
    if (r.archived) {
      return const FicheAdminActions(canEdit: false, canDelete: false, blockedReason: 'Fiche archivée : une demande de désarchivage est nécessaire.');
    }
    final route = ProdPaths.ficheEdit(compositeId: r.id, type: r.type, machine: r.machine, poste: r.poste);
    return FicheAdminActions(
      canEdit: route != null,
      canDelete: true,
      editRoute: route,
      blockedReason: route == null ? 'Machine ou équipe absente : modification impossible depuis cet écran.' : null,
    );
  }
}

String ficheTypeLabel(ProductionRecordModel r) => r.isProbar ? 'PROBAR' : 'PROMESH';

/// Suppression via les services EXISTANTS (DELETE /por-promesh/:id,
/// DELETE /industrial-records/:id) — l'id réel de la fiche, jamais son rang.
Future<void> deleteProductionFiche(ProductionRecordModel r) {
  final sep = r.id.indexOf(':');
  final id = sep >= 0 ? r.id.substring(sep + 1) : r.id;
  return r.isProbar ? IndustrialRecordService.instance.delete(id) : PorPromeshService.instance.delete(id);
}

/// Confirmation : numéro, type, avertissement « irréversible ».
/// Renvoie `true` uniquement sur « Confirmer la suppression ».
Future<bool> confirmFicheDeletion(BuildContext context, ProductionRecordModel r) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('fiche-delete-dialog'),
      title: Row(children: [
        const Icon(Icons.delete_forever_rounded, color: kCrmDanger, size: 26),
        const SizedBox(width: 10),
        Expanded(child: Text('Supprimer la fiche', style: tInter(fontSize: 17, fontWeight: FontWeight.w800, color: kCrmText))),
      ]),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _line('Numéro de la fiche', r.numero ?? '—', const ValueKey('fiche-delete-numero')),
          const SizedBox(height: 6),
          _line('Type de production', ficheTypeLabel(r), const ValueKey('fiche-delete-type')),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kCrmDanger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmDanger.withValues(alpha: 0.35))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, color: kCrmDanger, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cette action est irréversible : la fiche sera définitivement supprimée de la production, des statistiques et des récapitulatifs. '
                  'Une copie est conservée dans le journal d\'audit.',
                  key: const ValueKey('fiche-delete-warning'),
                  style: tInter(fontSize: 12.5, color: kCrmText),
                ),
              ),
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(key: const ValueKey('fiche-delete-cancel'), onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
        FilledButton.icon(
          key: const ValueKey('fiche-delete-confirm'),
          style: FilledButton.styleFrom(backgroundColor: kCrmDanger),
          onPressed: () => Navigator.of(ctx).pop(true),
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Confirmer la suppression'),
        ),
      ],
    ),
  );
  return ok == true;
}

Widget _line(String label, String value, Key key) => Row(children: [
      Text('$label : ', style: tInter(fontSize: 13, color: kCrmTextSub)),
      Flexible(child: Text(value, key: key, style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText))),
    ]);
