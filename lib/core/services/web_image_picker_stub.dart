import 'dart:async';
import 'dart:typed_data';

class WebImageResult {
  final Uint8List bytes;
  final int size;
  final String name;
  final String type;

  WebImageResult({
    required this.bytes,
    required this.size,
    required this.name,
    required this.type,
  });
}

Future<WebImageResult?> pickImageBytesWeb() async {
  return null;
}
