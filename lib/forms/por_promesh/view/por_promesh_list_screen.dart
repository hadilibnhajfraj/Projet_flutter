// lib/forms/por_promesh/view/por_promesh_list_screen.dart
//
// « Fiches de production PROMESH » (MyRoute.porPromeshListScreen, route et
// nom de classe inchangés). Présentation commune avec PROBAR :
// production_records/view/production_fiches_list_screen.dart (statistiques,
// filtres combinables, tableau, pagination — GET /production-records/fiches).
//
// Cet écran ne fournit que ce qui est propre à PROMESH, avec les MÊMES
// fonctions qu'auparavant : consultation (détail), modification par l'id de
// la fiche (parcours Machine → Poste → Modules), rapport PDF, impression,
// export Excel, suppression avec confirmation. Modifier et Supprimer ne sont
// jamais proposés sur une fiche verrouillée ; le backend revérifie chaque
// action (propriétaire, verrouillage).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/route/my_route.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/production_records/model/production_fiche_list.dart';
import 'package:dash_master_toolkit/production_records/view/production_fiches_list_screen.dart';

import '../service/por_promesh_service.dart';
import '../service/por_promesh_pdf_service.dart';
import '../service/por_promesh_excel_service.dart';

class PorPromeshListScreen extends StatelessWidget {
  const PorPromeshListScreen({super.key});

  // §CORRECTION ÉDITION PROMESH (2026-09-30) : la fiche est rouverte par son
  // id (jamais recherchée par machine/poste/date du jour, ce qui chargeait une
  // autre fiche ou créait un doublon).
  static String editRoute(FicheListRow r) {
    if (r.machine == null || r.poste == null) return MyRoute.productionPromeshRoot;
    return '${MyRoute.productionPromeshRoot}/machine/${r.machine}/poste/${r.poste}/modules?ficheId=${r.recordId}';
  }

  @override
  Widget build(BuildContext context) {
    void error(String prefix, Object e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$prefix : $e'), backgroundColor: Colors.red.shade700));
    }

    // Liste « light » : PDF / impression / Excel ont besoin de la fiche
    // complète, re-récupérée par id juste avant génération (comme avant).
    Future<void> exportPdf(FicheListRow r) async {
      try {
        await PorPromeshPdfService.instance.exportPdf(await PorPromeshService.instance.fetchById(r.recordId));
      } catch (e) {
        error('Erreur export PDF', e);
      }
    }

    Future<void> printPdf(FicheListRow r) async {
      try {
        await PorPromeshPdfService.instance.printPdf(await PorPromeshService.instance.fetchById(r.recordId));
      } catch (e) {
        error('Erreur impression', e);
      }
    }

    Future<void> exportExcel(FicheListRow r) async {
      try {
        PorPromeshExcelService.instance.export(await PorPromeshService.instance.fetchById(r.recordId));
      } catch (e) {
        error('Erreur export Excel', e);
      }
    }

    Future<void> delete(FicheListRow r) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Supprimer'),
          content: Text('Voulez-vous vraiment supprimer la fiche ${r.numero ?? r.date ?? ''} ?'),
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
        await PorPromeshService.instance.delete(r.recordId);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fiche supprimée')));
      } catch (e) {
        error('Erreur', e);
      }
    }

    return ProductionFichesListScreen(
      type: 'promesh',
      lineLabel: 'PROMESH',
      color: kPromeshColor,
      unit: 'm²',
      breadcrumbs: const [('Production', MyRoute.productionDashboardScreen), ('PROMESH', MyRoute.productionPromeshRoot), ('Fiches de production', null)],
      newFicheRoute: MyRoute.productionPromeshRoot,
      viewRoute: (r) => '${MyRoute.porPromeshDetailScreen}?id=${r.recordId}',
      onReport: exportPdf,
      canWrite: ficheListCanWrite,
      actions: [
        FicheListAction('edit', label: 'Modifier', icon: Icons.edit_outlined, color: kCrmInfo, requiresWrite: true, handler: (r) => r.isLocked ? null : (r) async => context.go(editRoute(r))),
        FicheListAction('print', label: 'Imprimer', icon: Icons.print_outlined, color: kCrmText, handler: (r) => printPdf),
        FicheListAction('excel', label: 'Export Excel', icon: Icons.grid_on_rounded, color: kCrmSuccess, handler: (r) => exportExcel),
        FicheListAction('delete', label: 'Supprimer', icon: Icons.delete_outline_rounded, color: kCrmDanger, reloadAfter: true, requiresWrite: true, handler: (r) => r.isLocked ? null : delete),
      ],
    );
  }
}
