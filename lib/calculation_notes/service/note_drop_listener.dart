// Glisser-déposer de fichiers depuis le système : écouteur du navigateur sur
// le Web, inactif ailleurs (tests VM) — même technique que la zone de dépôt
// du module Finance (événements dragover / drop de la fenêtre, zone active
// déterminée par les coordonnées de la souris).
export 'note_drop_listener_stub.dart' if (dart.library.html) 'note_drop_listener_web.dart';
