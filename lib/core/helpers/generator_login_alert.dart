import 'generator_login_alert_stub.dart'
    if (dart.library.html) 'generator_login_alert_web.dart' as impl;

Future<bool> requestGeneratorNotificationPermission() {
  return impl.requestGeneratorNotificationPermission();
}

void showGeneratorLoginNotification() {
  impl.showGeneratorLoginNotification();
}

Future<bool> sendGeneratorLoginEmail({
  required String username,
  required String accountEmail,
}) {
  return impl.sendGeneratorLoginEmail(
    username: username,
    accountEmail: accountEmail,
  );
}
