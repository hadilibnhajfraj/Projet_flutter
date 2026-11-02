// Fenêtre secondaire « Nouveau projet » ouverte depuis le formulaire de note
// de calcul. Elle héberge le formulaire de création du module Projets
// (ProjectFormScreen, mode intégré) : mêmes champs, mêmes validations, même
// POST /projects et mêmes droits — aucun second système de projets.
//
// Fichier séparé (fourni au formulaire de note par la route) : le formulaire
// projet dépend d'écrans Web, le formulaire de note reste testable hors
// navigateur.

import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/forms/view/project_form_screen.dart';

import '../model/calculation_note.dart';

Future<NoteProject?> showProjectCreateDialog(BuildContext context) {
  return showDialog<NoteProject>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 860),
        child: ProjectFormScreen(
          onProjectCreated: (project) => Navigator.of(ctx).pop(NoteProject.fromJson(project)),
        ),
      ),
    ),
  );
}
