import 'picked_file.dart';
import 'file_drop_helper_stub.dart' if (dart.library.html) 'file_drop_helper_web.dart' as impl;

typedef FileDropCallback = void Function(PickedFile file);

Object registerFileDrop(FileDropCallback callback) => impl.registerFileDrop(callback);
void unregisterFileDrop(Object registration) => impl.unregisterFileDrop(registration);
