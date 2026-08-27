import 'package:flutter/material.dart';

// §RESPONSIVE — MISSION CRM RESPONSIVE (§15/§17) : plusieurs Dialogs du CRM
// (Finance : shipment/invoice/purchase order/preview, Calendar, Users)
// fixaient leur contenu à une largeur/hauteur en dur (ex. `SizedBox(width:
// 900, height: 700, ...)`) à l'intérieur d'un `Dialog(insetPadding:
// EdgeInsets.all(24))` — correct en desktop, mais garanti de déborder
// horizontalement/verticalement sur un écran mobile plus étroit que
// `largeur + 48` (RenderFlex/bottom/right overflow, exactement le symptôme
// décrit dans le ticket). `ResponsiveDialogBox` borne la taille désirée à
// l'espace réellement disponible (écran - insetPadding) : identique au
// rendu desktop/tablette existant tant que ça tient, jamais de débordement
// quand ça ne tient pas — les Dialogs concernés n'ont qu'à remplacer leur
// `SizedBox(width: W, height: H, child: X)` par
// `ResponsiveDialogBox(width: W, height: H, child: X)`, sans autre changement.
class ResponsiveDialogBox extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;

  // Doit correspondre à l'insetPadding du Dialog parent (EdgeInsets.all(24)
  // dans tous les appelants actuels) — sinon la taille calculée ici serait
  // trop grande de la différence et le débordement réapparaîtrait.
  final double insetPadding;

  const ResponsiveDialogBox({
    super.key,
    required this.width,
    required this.height,
    required this.child,
    this.insetPadding = 24,
  });

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final maxW = screen.width - insetPadding * 2;
    final maxH = screen.height - insetPadding * 2;
    final w = width > maxW ? maxW : width;
    final h = height > maxH ? maxH : height;
    return SizedBox(width: w, height: h, child: child);
  }
}
