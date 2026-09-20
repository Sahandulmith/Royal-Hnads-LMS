// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
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
  final completer = Completer<WebImageResult?>();
  final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
  uploadInput.style.display = 'none';
  html.document.body?.children.add(uploadInput);

  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final fileSize = file.size; // Original file size in bytes
      final fileName = file.name;
      final fileType = file.type.isNotEmpty ? file.type : 'image/jpeg';

      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((e) {
        Uint8List? dataBytes;
        if (reader.result is Uint8List) {
          dataBytes = reader.result as Uint8List;
        } else if (reader.result is List<int>) {
          dataBytes = Uint8List.fromList(reader.result as List<int>);
        }

        if (dataBytes != null && !completer.isCompleted) {
          completer.complete(WebImageResult(
            bytes: dataBytes,
            size: fileSize,
            name: fileName,
            type: fileType,
          ));
        } else if (!completer.isCompleted) {
          completer.complete(null);
        }
      });
      reader.onError.listen((e) {
        if (!completer.isCompleted) completer.complete(null);
      });
    } else {
      if (!completer.isCompleted) completer.complete(null);
    }
  });

  // Handle user canceling file picker dialog when window regains focus
  void onFocus(html.Event e) {
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });
  }

  html.window.addEventListener('focus', onFocus, true);

  // Trigger file selection dialog after setting up listeners
  uploadInput.click();

  final result = await completer.future;
  html.window.removeEventListener('focus', onFocus, true);
  uploadInput.remove();
  return result;
}
