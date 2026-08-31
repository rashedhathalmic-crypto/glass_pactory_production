// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

void clearGeneratorEmailLinkFromAddressBar() {
  try {
    final uri = Uri.base;
    final clean = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    );
    html.window.history.replaceState(null, html.document.title, clean.toString());
  } on Object {
    // URL cleanup is best-effort only; authentication has already completed.
  }
}
