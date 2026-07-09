import 'picked_file.dart';
import 'file_picker_helper_stub.dart'
    if (dart.library.html) 'file_picker_helper_web.dart' as impl;

Future<List<PickedFile>> pickFiles({
  required List<String> extensions,
  bool allowMultiple = false,
}) {
  return impl.pickFiles(extensions: extensions, allowMultiple: allowMultiple);
}
