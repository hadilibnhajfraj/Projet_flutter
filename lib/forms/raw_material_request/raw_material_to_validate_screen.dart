// lib/forms/raw_material_request/raw_material_to_validate_screen.dart
//
// Page « Production → Matières premières → Demandes à valider » : accès
// permanent du responsable logistique achats aux demandes sans décision
// (en attente de validation ou soumises), indépendant de la popup de
// connexion. Même contenu et mêmes actions que la popup
// (RawMaterialPendingReview), toutes les demandes affichées ; données
// relues depuis le backend à l'ouverture et après chaque décision.

import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';

import 'raw_material_pending_prompt.dart';
import 'raw_material_tracking_service.dart';

class RawMaterialToValidateScreen extends StatelessWidget {
  /// Injection pour les tests ; par défaut, API réelle.
  final RawMaterialTrackingApi? api;

  /// Nouveau compteur (badge du menu).
  final ValueChanged<int>? onCountChanged;

  const RawMaterialToValidateScreen({super.key, this.api, this.onCountChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              color: kCrmSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kCrmBorder),
            ),
            child: RawMaterialPendingReview(
              api: api ?? RawMaterialTrackingService.instance,
              onCountChanged: onCountChanged,
            ),
          ),
        ),
      ),
    );
  }
}
