// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'picked_file.dart';

class _Registration {
  _Registration(this.subscriptions);
  final List<StreamSubscription<html.Event>> subscriptions;
}

Object registerFileDrop(void Function(PickedFile file) callback) {
  final subscriptions = <StreamSubscription<html.Event>>[];
  subscriptions.add(html.document.onDragOver.listen((event) => event.preventDefault()));
  subscriptions.add(html.document.onDrop.listen((event) async {
    event.preventDefault();
    final files = event.dataTransfer.files;
    if (files.isEmpty || !files.first.name.toLowerCase().endsWith('.dxf')) return;
    final file = files.first;
    final reader = html.FileReader()..readAsArrayBuffer(file);
    await reader.onLoadEnd.first;
    callback(PickedFile(fileName: file.name, bytes: reader.result as Uint8List, contentType: file.type));
  }));
  return _Registration(subscriptions);
}

void unregisterFileDrop(Object registration) {
  if (registration is _Registration) for (final subscription in registration.subscriptions) { subscription.cancel(); }
}
