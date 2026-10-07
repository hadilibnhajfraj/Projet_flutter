// lib/quality_control/service/qc_file_saver.dart
//
// Téléchargement d'un fichier généré par le backend (export Excel / PDF /
// CSV du module Contrôle Qualité). Web : lien de téléchargement du
// navigateur ; VM (tests) : implémentation sans dart:html qui mémorise le
// dernier fichier « enregistré ».

export 'qc_file_saver_stub.dart' if (dart.library.html) 'qc_file_saver_web.dart';
