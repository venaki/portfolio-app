import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<String?> pickTextFile({String accept = '.json'}) {
  final completion = Completer<String?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept;
  void finish(String? text, [Object? error]) {
    input.remove();
    if (completion.isCompleted) return;
    if (error != null) {
      completion.completeError(error);
    } else {
      completion.complete(text);
    }
  }

  input.addEventListener(
    'cancel',
    ((web.Event _) {
      finish(null);
    }).toJS,
  );
  input.onchange = ((web.Event _) {
    final file = input.files?.item(0);
    if (file == null) {
      finish(null);
      return;
    }
    if (file.size > 20 * 1024 * 1024) {
      finish(null, const FormatException('파일은 20MB 이하여야 합니다.'));
      return;
    }
    final reader = web.FileReader();
    reader.onload = ((web.Event _) {
      finish((reader.result as JSString).toDart);
    }).toJS;
    reader.onerror = ((web.Event _) {
      finish(null, StateError('파일을 읽을 수 없습니다.'));
    }).toJS;
    reader.readAsText(file, 'UTF-8');
  }).toJS;
  input.click();
  return completion.future;
}

void downloadText({
  required String text,
  required String fileName,
  String mimeType = 'application/json',
}) {
  final blob = web.Blob(
    [text.toJS].toJS,
    web.BlobPropertyBag(type: '$mimeType;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  Timer(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
}
