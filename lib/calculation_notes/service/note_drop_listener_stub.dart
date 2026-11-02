import 'dart:typed_data';
import 'dart:ui';

typedef NoteDroppedFile = ({String name, Uint8List bytes});

class NoteDropListener {
  NoteDropListener({required void Function(Offset position) onDragOver, required void Function(Offset position, List<NoteDroppedFile> files) onDrop});

  void dispose() {}
}
