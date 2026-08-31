import 'generator_login_alert_stub.dart'
    if (dart.library.html) 'generator_login_alert_web.dart' as impl;

Future<bool> requestGeneratorNotificationPermission() {
  return impl.requestGeneratorNotificationPermission();
}

void showGeneratorLoginNotification({
  String title = 'Glass CNC Tools',
  String body = 'تم تسجيل الدخول بنجاح.',
}) {
  impl.showGeneratorLoginNotification(title: title, body: body);
}

Future<Map<String, dynamic>> checkGeneratorApprovalService() {
  return impl.checkGeneratorApprovalService();
}

Future<Map<String, dynamic>> createGeneratorAccessRequest({
  required String requesterName,
  required String idToken,
  required String tool,
}) {
  return impl.createGeneratorAccessRequest(
    requesterName: requesterName,
    idToken: idToken,
    tool: tool,
  );
}

Future<Map<String, dynamic>> verifyGeneratorAccessOtp({
  required String requestId,
  required String pollToken,
  required String otp,
  required String idToken,
}) {
  return impl.verifyGeneratorAccessOtp(
    requestId: requestId,
    pollToken: pollToken,
    otp: otp,
    idToken: idToken,
  );
}

Future<Map<String, dynamic>> pollGeneratorAccessRequest({
  required String requestId,
  required String pollToken,
}) {
  return impl.pollGeneratorAccessRequest(
    requestId: requestId,
    pollToken: pollToken,
  );
}

// Approval persistence is intentionally disabled for the OTP flow. A fresh
// password + OTP is required after every page reload/new browser session.
DateTime? readGeneratorApprovalExpiry() => null;
void saveGeneratorApprovalExpiry(DateTime approvedUntil) {}
void clearGeneratorApproval() {}

Future<bool> sendGeneratorLoginEmail({
  required String username,
  required String accountEmail,
}) async {
  return false;
}
