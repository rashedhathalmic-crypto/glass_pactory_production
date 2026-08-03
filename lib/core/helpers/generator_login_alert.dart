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

Future<Map<String, dynamic>> pollGeneratorAccessRequest({
  required String requestId,
  required String pollToken,
}) {
  return impl.pollGeneratorAccessRequest(
    requestId: requestId,
    pollToken: pollToken,
  );
}

DateTime? readGeneratorApprovalExpiry() {
  return impl.readGeneratorApprovalExpiry();
}

void saveGeneratorApprovalExpiry(DateTime approvedUntil) {
  impl.saveGeneratorApprovalExpiry(approvedUntil);
}

void clearGeneratorApproval() {
  impl.clearGeneratorApproval();
}

// Kept for source compatibility. Login email is now sent by the approval
// service, not by an unauthenticated third-party form endpoint.
Future<bool> sendGeneratorLoginEmail({
  required String username,
  required String accountEmail,
}) async {
  return false;
}
