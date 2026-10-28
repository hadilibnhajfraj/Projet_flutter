// lib/forms/por_promesh/view/por_promesh_dashboard_screen.dart
//
// Accueil des comptes de production et des responsables (menu « Tableau de
// bord », MyRoute.porPromeshDashboardScreen) : le TABLEAU DE BORD INDUSTRIEL
// commun (production_dashboard_screen.dart — KPI, alertes, statuts, machines,
// dernières fiches et demandes), complété des modules propres à cet accueil :
// Maintenance, Mélange et Récupérables (compteurs et accès rapides conservés
// de l'ancienne page). Le nom de fichier/classe est conservé (référencé par
// le routeur et le menu latéral).

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as fm show Text;
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/forms/industrial/model/industrial_record_model.dart';
import 'package:dash_master_toolkit/forms/industrial/service/industrial_record_service.dart';
import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/forms/recuperables/model/recuperable_models.dart';
import 'package:dash_master_toolkit/forms/recuperables/service/recuperable_service.dart';
import 'package:dash_master_toolkit/forms/recuperables/theme/recuperable_theme.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/production_dashboard/model/production_dashboard_model.dart' show prodFormatNumber;
import 'package:dash_master_toolkit/production_dashboard/view/production_dashboard_screen.dart';
import 'package:dash_master_toolkit/quality_control/quality_control_i18n.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_widgets.dart';
import 'package:dash_master_toolkit/route/my_route.dart';

class PorPromeshDashboardScreen extends StatelessWidget {
  const PorPromeshDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => const ProductionDashboardScreen(extraSections: [_OtherModulesSection()]);
}

/// Maintenance, Mélange, Récupérables : compteurs réels et accès rapides.
class _OtherModulesSection extends StatefulWidget {
  const _OtherModulesSection();

  @override
  State<_OtherModulesSection> createState() => _OtherModulesSectionState();
}

class _OtherModulesSectionState extends State<_OtherModulesSection> {
  bool _loading = true;
  String? _error;
  List<IndustrialRecordModel> _maintenance = [];
  List<IndustrialRecordModel> _melange = [];
  List<RecuperableFicheModel> _recuperables = [];

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
      final results = await Future.wait([
        IndustrialRecordService.instance.fetchAll(module: 'maintenance', forceRefresh: true),
        IndustrialRecordService.instance.fetchAll(module: 'melange', forceRefresh: true),
        RecuperableService.instance.fetchAll(),
      ]);
      if (!mounted) return;
      setState(() {
        _maintenance = results[0] as List<IndustrialRecordModel>;
        _melange = results[1] as List<IndustrialRecordModel>;
        _recuperables = results[2] as List<RecuperableFicheModel>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context);
    String v(int n) => _loading ? '…' : '$n';
    final ouvertes = _recuperables.where((f) => f.isOpen).length;
    final poids = _recuperables.fold(0.0, (s, f) => s + f.totalDechetKg);
    Widget link(String id, IconData icon, String label, Color color, String route) => OutlinedButton.icon(
          key: ValueKey('home-link-$id'),
          onPressed: () => context.go(route),
          style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color.withValues(alpha: 0.35)), minimumSize: const Size(0, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
          icon: Icon(icon, size: 16),
          label: Text(label, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText)),
        );
    return QcSection(
      key: const ValueKey('home-other-modules'),
      icon: Icons.apps_rounded,
      title: 'Autres modules',
      subtitle: 'Maintenance, Mélange et Récupérables',
      color: kProductionColor,
      trailing: IconButton(tooltip: qcT('Actualiser'), onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded, size: 18, color: kCrmTextSub)),
      children: [
        if (_error != null)
          QcErrorBanner(_error!, onRetry: _load)
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: qcGrid(columns: (w) => w >= 1000 ? 4 : (w >= 560 ? 2 : 1), [
              QcKpiTile(icon: Icons.build_outlined, label: 'Demandes Maintenance', value: v(_maintenance.length), color: kMaintenanceColor),
              QcKpiTile(icon: Icons.science_outlined, label: 'Fiches Mélange', value: v(_melange.length), color: kMelangeColor),
              QcKpiTile(icon: Icons.recycling_rounded, label: 'Récupérables ouvertes', value: v(ouvertes), caption: _loading ? null : qcT('{} terminée(s)').replaceFirst('{}', '${_recuperables.length - ouvertes}'), color: kRecuperableColor),
              QcKpiTile(
                icon: Icons.scale_outlined,
                label: 'Poids total récupéré',
                value: null,
                valueWidget: fm.Text(_loading ? '…' : '${prodFormatNumber(poids, maxDecimals: 1)} kg', style: tInter(fontSize: 20, fontWeight: FontWeight.w800, color: kCrmText)),
                color: kRecuperableColor,
              ),
            ]),
          ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          link('maintenance-new', Icons.add_circle_outline, 'Nouvelle maintenance', kMaintenanceColor, MyRoute.maintenanceFormScreen),
          link('maintenance-history', Icons.history_outlined, 'Historique Maintenance', kMaintenanceColor, MyRoute.maintenanceHistoriqueScreen),
          link('promesh-history', Icons.history_outlined, 'Historique PROMESH', kPromeshColor, MyRoute.porPromeshHistoriqueScreen),
          link('probar-history', Icons.history_outlined, 'Historique PROBAR', kProbarColor, MyRoute.probarListScreen),
          link('recuperables-new', Icons.add_circle_outline, 'Nouvelle fiche Récupérables', kRecuperableColor, MyRoute.recuperableFicheScreen),
        ]),
      ],
    );
  }
}
