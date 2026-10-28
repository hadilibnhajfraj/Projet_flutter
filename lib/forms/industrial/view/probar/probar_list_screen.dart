// lib/forms/industrial/view/probar/probar_list_screen.dart
//
// « Fiches de production PROBAR » (MyRoute.probarListScreen) — même
// présentation que PROMESH (production_records/view/
// production_fiches_list_screen.dart). Actions propres à PROBAR, avec les
// fonctions EXISTANTES de la ligne : consultation (détail par machine/poste),
// modification (ProbarController.bootstrapWithId → page Modules, comme le
// détail), suppression avec confirmation (IndustrialRecordService.delete).
// Les exports PROBAR n'existant pas encore, aucun bouton « Rapport ».
// Modifier et Supprimer ne sont jamais proposés sur une fiche verrouillée ; le
// backend revérifie chaque action.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/route/my_route.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/production_records/model/production_fiche_list.dart';
import 'package:dash_master_toolkit/production_records/view/production_fiches_list_screen.dart';

import '../../controller/probar_controller.dart';
import '../../service/industrial_record_service.dart';

class ProbarListScreen extends StatelessWidget {
  const ProbarListScreen({super.key});

  static String _base(FicheListRow r) => '${MyRoute.productionProbarRoot}/machine/${r.machine ?? '1'}/poste/${r.poste ?? 'matin'}';

  @override
  Widget build(BuildContext context) {
    String t(String k) => AppLocalizations.of(context).translate(k);

    Future<void> edit(FicheListRow r) async {
      final c = Get.isRegistered<ProbarController>() ? Get.find<ProbarController>() : Get.put(ProbarController(), permanent: true);
      await c.bootstrapWithId(r.machine ?? '1', r.poste ?? 'matin', r.recordId);
      if (context.mounted) context.go('${_base(r)}/modules?ficheId=${r.recordId}');
    }

    Future<void> delete(FicheListRow r) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(t('Supprimer la fiche ?')),
          content: Text(t('Cette action est irréversible. La fiche sera définitivement supprimée.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Annuler'))),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: kCrmDanger), onPressed: () => Navigator.pop(ctx, true), child: Text(t('Supprimer'))),
          ],
        ),
      );
      if (confirm != true) return;
      try {
        await IndustrialRecordService.instance.delete(r.recordId);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t('Erreur')} : $e'), backgroundColor: kCrmDanger));
        }
      }
    }

    return ProductionFichesListScreen(
      type: 'probar',
      lineLabel: 'PROBAR',
      color: kProbarColor,
      unit: 'ml',
      breadcrumbs: const [('Production', MyRoute.productionDashboardScreen), ('PROBAR', MyRoute.productionProbarRoot), ('Fiches de production', null)],
      newFicheRoute: MyRoute.productionProbarRoot,
      viewRoute: (r) => '${_base(r)}/detail?id=${r.recordId}',
      canWrite: ficheListCanWrite,
      actions: [
        FicheListAction('edit', label: 'Modifier', icon: Icons.edit_outlined, color: kCrmInfo, requiresWrite: true, handler: (r) => r.isLocked ? null : edit),
        FicheListAction('delete', label: 'Supprimer', icon: Icons.delete_outline_rounded, color: kCrmDanger, reloadAfter: true, requiresWrite: true, handler: (r) => r.isLocked ? null : delete),
      ],
    );
  }
}
