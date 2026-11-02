import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui';

typedef NoteDroppedFile = ({String name, Uint8List bytes});

class NoteDropListener {
  final void Function(Offset position) onDragOver;
  final void Function(Offset position, List<NoteDroppedFile> files) onDrop;
  late final StreamSubscription<html.MouseEvent> _over;
  late final StreamSubscription<html.MouseEvent> _drop;
  bool _disposed = false;

  NoteDropListener({required this.onDragOver, required this.onDrop}) {
    _over = html.window.onDragOver.listen((e) {
      if (_disposed) return;
      e.preventDefault(); // sans cela, le navigateur refuse le dépôt
      onDragOver(Offset(e.client.x.toDouble(), e.client.y.toDouble()));
    });
    _drop = html.window.onDrop.listen((e) async {
      if (_disposed) return;
      e.preventDefault(); // jamais d'ouverture du fichier par le navigateur
      final pos = Offset(e.client.x.toDouble(), e.client.y.toDouble());
      final files = <NoteDroppedFile>[];
      for (final f in e.dataTransfer.files ?? const <html.File>[]) {
        final bytes = await _read(f);
        if (_disposed) return;
        if (bytes != null) files.add((name: f.name, bytes: bytes));
      }
      onDrop(pos, files);
    });
  }

  Future<Uint8List?> _read(html.File file) {
    final c = Completer<Uint8List?>();
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      final r = reader.result;
      c.complete(r is Uint8List ? r : null);
    });
    reader.onError.listen((_) => c.complete(null));
    reader.readAsArrayBuffer(file);
    return c.future;
  }

  void dispose() {
    _disposed = true;
    _over.cancel();
    _drop.cancel();
  }
}
