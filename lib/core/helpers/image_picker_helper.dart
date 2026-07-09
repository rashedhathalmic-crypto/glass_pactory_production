import 'picked_image_file.dart';
import 'image_picker_helper_stub.dart'
    if (dart.library.html) 'image_picker_helper_web.dart' as impl;

Future<List<PickedImageFile>> pickImages({bool allowMultiple = true}) {
  return impl.pickImages(allowMultiple: allowMultiple);
}
