// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> saveNoteFile(Uint8List bytes, String filename, String mimeType) async {
  final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes], mimeType));
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
