import 'open_url_helper_stub.dart'
    if (dart.library.html) 'open_url_helper_web.dart' as impl;

Future<void> openExternalUrl(String url) => impl.openExternalUrl(url);
