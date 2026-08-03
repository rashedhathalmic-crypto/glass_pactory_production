Future<bool> requestGeneratorNotificationPermission() async => false;

void showGeneratorLoginNotification({
  required String title,
  required String body,
}) {}

Future<Map<String, dynamic>> checkGeneratorApprovalService() async {
  return {
    'status': 'unsupported',
    'message': 'نظام الموافقة متاح في نسخة الويب فقط.',
  };
}

Future<Map<String, dynamic>> createGeneratorAccessRequest({
  required String requesterName,
  required String idToken,
  required String tool,
}) async {
  return {
    'status': 'unsupported',
    'message': 'نظام الموافقة متاح في نسخة الويب فقط.',
  };
}

Future<Map<String, dynamic>> pollGeneratorAccessRequest({
  required String requestId,
  required String pollToken,
}) async {
  return {
    'status': 'unsupported',
    'message': 'نظام الموافقة متاح في نسخة الويب فقط.',
  };
}

DateTime? readGeneratorApprovalExpiry() => null;

void saveGeneratorApprovalExpiry(DateTime approvedUntil) {}

void clearGeneratorApproval() {}

Future<bool> sendGeneratorLoginEmail({
  required String username,
  required String accountEmail,
}) async {
  return false;
}
