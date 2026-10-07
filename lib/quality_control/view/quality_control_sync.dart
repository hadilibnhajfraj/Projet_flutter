// lib/quality_control/view/quality_control_sync.dart
//
// Synchronisation des écrans du module CONTRÔLE QUALITÉ avec PostgreSQL.
//
// Les pages accueil → ligne → machine sont des routes IMBRIQUÉES : elles
// restent montées dans la pile pendant qu'on travaille plus loin (machine,
// formulaire). Sans écoute, leurs compteurs resteraient ceux du premier
// chargement. Ce mixin relit l'API :
// - après chaque écriture réussie (QualityControlService.revision) ;
// - quand la période partagée change (QualityControlService.period).
// Aucun compteur n'est jamais modifié localement.

import 'package:flutter/widgets.dart';

import '../service/quality_control_service.dart';

mixin QcSyncMixin<T extends StatefulWidget> on State<T> {
  QualityControlService get qcService => QualityControlService.instance;

  /// Période partagée (today | week | month | year | all).
  String get qcPeriod => qcService.period.value;

  void qcSetPeriod(String period) => qcService.period.value = period;

  /// Relit les données de l'écran depuis l'API.
  Future<void> qcReload();

  @override
  void initState() {
    super.initState();
    qcService.revision.addListener(_onQcSync);
    qcService.period.addListener(_onQcSync);
  }

  void _onQcSync() {
    if (mounted) qcReload();
  }

  @override
  void dispose() {
    qcService.revision.removeListener(_onQcSync);
    qcService.period.removeListener(_onQcSync);
    super.dispose();
  }
}
