// Enregistrement d'un fichier téléchargé : navigateur (Blob) sur le Web,
// sans effet ailleurs (tests VM) — garde les écrans testables hors navigateur.
export 'note_file_saver_stub.dart' if (dart.library.html) 'note_file_saver_web.dart';
