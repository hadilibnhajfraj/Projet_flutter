// lib/quality_control/view/quality_control_widgets.dart
//
// Petites briques partagées par les écrans du module CONTRÔLE QUALITÉ —
// mêmes tokens que le module industriel (pipeline_theme / industrial_theme).

import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import '../model/quality_control_model.dart';

// Couleur d'accent du module (distincte de PROMESH/PROBAR/MÉLANGE/MAINTENANCE).
const Color kQualityControlColor = Color(0xFF0EA5E9);

Color qualityStatusColor(String status) {
  switch (status) {
    case 'CONFORME':
      return kCrmSuccess;
    case 'NON_CONFORME':
      return kCrmDanger;
    case 'EN_COURS':
      return kCrmWarning;
    default:
      return kCrmTextSub;
  }
}

class QualityStatusPill extends StatelessWidget {
  final String status;
  final Map<String, String> labels;
  const QualityStatusPill(this.status, {super.key, this.labels = kControlStatusLabels});

  @override
  Widget build(BuildContext context) {
    final color = qualityStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(labels[status] ?? status, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

Color productionTypeColor(String type) => type.toUpperCase() == 'PROBAR' ? kProbarColor : kPromeshColor;
