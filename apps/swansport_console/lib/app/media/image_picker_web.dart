import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'image_picker.dart';

Future<PickedImageFile?> pickImageFile() async {
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = '.png,.jpg,.jpeg,.webp,.svg,image/png,image/jpeg,image/webp,image/svg+xml'
    ..multiple = false
    ..style.display = 'none';
  web.document.body?.appendChild(input);
  final completer = Completer<PickedImageFile?>();
  web.FileReader? reader;
  Timer? cancelTimer;
  bool reading = false;
  late JSFunction change, cancel, focus, load, error;
  void finish(PickedImageFile? result, [Object? failure]) {
    if (completer.isCompleted) return;
    input.removeEventListener('change', change);
    input.removeEventListener('cancel', cancel);
    web.window.removeEventListener('focus', focus);
    if (reader != null) {
      reader!.removeEventListener('load', load);
      reader!.removeEventListener('error', error);
      reader!.removeEventListener('abort', error);
    }
    cancelTimer?.cancel(); input.remove();
    if (failure == null) { completer.complete(result); }
    else { completer.completeError(failure); }
  }
  load = ((web.Event _) {
    try {
      final buffer = (reader!.result as JSArrayBuffer).toDart;
      final file = input.files!.item(0)!;
      finish(PickedImageFile(bytes: buffer.asUint8List(), name: file.name, mimeType: file.type));
    } catch (e) { finish(null, e); }
  }).toJS;
  error = ((web.Event _) => finish(null, StateError('Görsel okunamadı'))).toJS;
  change = ((web.Event _) {
    final file = input.files?.item(0);
    if (file == null) { finish(null); return; }
    if (file.size > 5 * 1024 * 1024) { finish(null, ArgumentError('Logo en fazla 5 MB olabilir')); return; }
    reading = true;
    reader = web.FileReader();
    reader!.addEventListener('load', load);
    reader!.addEventListener('error', error);
    reader!.addEventListener('abort', error);
    try { reader!.readAsArrayBuffer(file); } catch (e) { finish(null, e); }
  }).toJS;
  cancel = ((web.Event _) => finish(null)).toJS;
  // Fallback for browsers without the input cancel event.
  focus = ((web.Event _) {
    cancelTimer?.cancel();
    cancelTimer = Timer(const Duration(milliseconds: 500), () {
      if (!reading && (input.files?.length ?? 0) == 0) finish(null);
    });
  }).toJS;
  input.addEventListener('change', change);
  input.addEventListener('cancel', cancel);
  web.window.addEventListener('focus', focus);
  try { input.click(); } catch (e) { finish(null, e); }
  return completer.future;
}
