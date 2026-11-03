// lib/production_records/view/fiche_edit_mode_widgets.dart
//
// Grille des modules PROBAR / PROMESH en MODE MODIFICATION (fiche existante
// ouverte par « Modifier » du root admin — voir FicheEditSession) : bandeau
// explicite et bouton « Terminer la modification » qui ramène à la liste
// d'origine (rechargée à l'ouverture). Chaque module enregistre la fiche par
// son id (PUT existant) : aucune nouvelle validation n'est déclenchée.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';

import '../fiche_edit_session.dart';

class FicheEditModeBanner extends StatelessWidget {
  final String lineLabel; // PROBAR | PROMESH
  final Color color;
  const FicheEditModeBanner({super.key, required this.lineLabel, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('fiche-edit-mode-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.edit_note_rounded, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Modification d\'une fiche $lineLabel existante', style: tInter(fontSize: 14, fontWeight: FontWeight.w800, color: kCrmText)),
            const SizedBox(height: 4),
            Text(
              'Les données enregistrées sont chargées. Ouvrez un module, modifiez-le puis enregistrez : '
              'la modification porte uniquement sur cette fiche.',
              style: tInter(fontSize: 12.5, color: kCrmTextSub),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Termine la modification : ferme le mode modification et revient à la liste
/// d'origine (sinon [fallbackRoute]).
void finishFicheEdit(BuildContext context, String ficheId, {required String fallbackRoute, bool showConfirmation = true}) {
  final route = FicheEditSession.end(ficheId) ?? fallbackRoute;
  if (showConfirmation) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modification terminée.'), backgroundColor: kCrmSuccess));
  }
  context.go(route);
}

class FicheEditFinishButton extends StatelessWidget {
  final String ficheId;
  final String fallbackRoute;
  const FicheEditFinishButton({super.key, required this.ficheId, required this.fallbackRoute});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton.icon(
        key: const ValueKey('fiche-edit-finish'),
        onPressed: () => finishFicheEdit(context, ficheId, fallbackRoute: fallbackRoute),
        icon: const Icon(Icons.check_circle_rounded, size: 24),
        label: Text('TERMINER LA MODIFICATION', style: tInter(fontSize: 17, fontWeight: FontWeight.w900)),
        style: ElevatedButton.styleFrom(
          backgroundColor: kCrmInfo,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
