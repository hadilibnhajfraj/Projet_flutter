// Implémentation hors navigateur (tests VM) : aucun téléchargement réel,
// le dernier fichier est conservé pour vérification.

import 'dart:typed_data';

class QcSavedFile {
  final String name;
  final String mimeType;
  final Uint8List bytes;
  const QcSavedFile(this.name, this.mimeType, this.bytes);
}

QcSavedFile? qcLastSavedFile;

Future<void> saveQcFile(Uint8List bytes, String fileName, String mimeType) async {
  qcLastSavedFile = QcSavedFile(fileName, mimeType, bytes);
}
