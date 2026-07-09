import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../utils/exceptions/exceptions.dart';

class StorageService {
  StorageService(this._storage);

  final FirebaseStorage _storage;

  Reference _orderAttachmentsRef(String orderId, String fileName) {
    return _storage.ref().child('orders/$orderId/$fileName');
  }

  Future<String> uploadOrderAttachment({
    required String orderId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      final ref = _orderAttachmentsRef(orderId, fileName);
      final metadata = SettableMetadata(contentType: contentType);
      await ref.putData(bytes, metadata);
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw StorageException(
        e.message ?? 'Failed to upload file',
        code: e.code,
      );
    }
  }

  Future<void> deleteOrderAttachment({
    required String orderId,
    required String fileName,
  }) async {
    try {
      await _orderAttachmentsRef(orderId, fileName).delete();
    } on FirebaseException catch (e) {
      throw StorageException(
        e.message ?? 'Failed to delete file',
        code: e.code,
      );
    }
  }

  Future<List<String>> listOrderAttachments(String orderId) async {
    try {
      final result = await _storage.ref().child('orders/$orderId').listAll();
      final urls = <String>[];
      for (final item in result.items) {
        urls.add(await item.getDownloadURL());
      }
      return urls;
    } on FirebaseException catch (e) {
      throw StorageException(
        e.message ?? 'Failed to list attachments',
        code: e.code,
      );
    }
  }
}
