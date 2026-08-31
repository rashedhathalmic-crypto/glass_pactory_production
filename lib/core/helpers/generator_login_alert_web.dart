// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';

const _defaultApprovalServiceUrl =
    'https://script.google.com/macros/s/'
    'AKfycbxwidW-HceCIzOnF8jNx3Ewl5tkKvtjHDRNni75mbGi/exec';
const _approvalServiceUrl = String.fromEnvironment(
  'ACCESS_APPROVAL_URL',
  defaultValue: _defaultApprovalServiceUrl,
);
const _otpLifetime = Duration(minutes: 10);

Future<bool> requestGeneratorNotificationPermission() async {
  try {
    if (!html.Notification.supported) return false;
    if (html.Notification.permission == 'granted') return true;
    return await html.Notification.requestPermission() == 'granted';
  } on Object {
    return false;
  }
}

void showGeneratorLoginNotification({
  required String title,
  required String body,
}) {
  try {
    if (html.Notification.supported &&
        html.Notification.permission == 'granted') {
      html.Notification(title, body: body);
    }
  } on Object {
    // Notifications are optional.
  }
}

String _randomHex(int byteCount) {
  final random = Random.secure();
  final buffer = StringBuffer();
  for (var index = 0; index < byteCount; index++) {
    buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

void _addHiddenField(html.FormElement form, String name, String value) {
  form.children.add(
    html.InputElement()
      ..type = 'hidden'
      ..name = name
      ..value = value,
  );
}

Future<void> _submitHiddenForm(Map<String, String> fields) async {
  final body = html.document.body;
  if (body == null) {
    throw StateError('Document body unavailable');
  }

  final frameName =
      'glass_cnc_otp_${DateTime.now().microsecondsSinceEpoch}_${_randomHex(4)}';
  final iframe = html.IFrameElement()
    ..name = frameName
    ..style.display = 'none';
  final form = html.FormElement()
    ..method = 'POST'
    ..action = _approvalServiceUrl
    ..target = frameName
    ..style.display = 'none';

  for (final entry in fields.entries) {
    _addHiddenField(form, entry.key, entry.value);
  }

  body.children
    ..add(iframe)
    ..add(form);

  try {
    form.submit();
    await Future<void>.delayed(const Duration(milliseconds: 650));
  } finally {
    form.remove();
    iframe.remove();
  }
}

Future<Map<String, dynamic>> _serviceQuery(
  Map<String, String> queryParameters,
) async {
  final body = html.document.body;
  if (body == null) {
    return {
      'status': 'error',
      'message': 'تعذر قراءة استجابة خدمة OTP.',
    };
  }

  final storageKey =
      'glass_cnc_otp_${DateTime.now().microsecondsSinceEpoch}_${_randomHex(4)}';
  html.window.localStorage.remove(storageKey);

  final uri = Uri.parse(_approvalServiceUrl).replace(
    queryParameters: {
      ...queryParameters,
      'storageKey': storageKey,
      '_': DateTime.now().millisecondsSinceEpoch.toString(),
    },
  );

  final script = html.ScriptElement()
    ..src = uri.toString()
    ..async = true;
  final loaded = Completer<void>();

  late final StreamSubscription<html.Event> loadSubscription;
  late final StreamSubscription<html.Event> errorSubscription;

  loadSubscription = script.onLoad.listen((_) {
    if (!loaded.isCompleted) loaded.complete();
  });
  errorSubscription = script.onError.listen((_) {
    if (!loaded.isCompleted) {
      loaded.completeError(StateError('OTP service script failed to load'));
    }
  });

  body.children.add(script);

  try {
    await loaded.future.timeout(const Duration(seconds: 12));
    final raw = html.window.localStorage[storageKey];
    if (raw == null || raw.isEmpty) {
      return {
        'status': 'error',
        'message':
            'خدمة OTP غير منشورة أو رابط Google Apps Script غير صحيح.',
      };
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return {
        'status': 'error',
        'message': 'استجابة خدمة OTP غير صحيحة.',
      };
    }
    return Map<String, dynamic>.from(decoded);
  } on TimeoutException {
    return {
      'status': 'error',
      'message': 'انتهت مهلة الاتصال بخدمة OTP.',
    };
  } on Object {
    return {
      'status': 'error',
      'message': 'تعذر الاتصال بخدمة OTP.',
    };
  } finally {
    await loadSubscription.cancel();
    await errorSubscription.cancel();
    script.remove();
    html.window.localStorage.remove(storageKey);
  }
}

Future<Map<String, dynamic>> checkGeneratorApprovalService() async {
  if (!_approvalServiceUrl.startsWith('https://') ||
      !_approvalServiceUrl.endsWith('/exec')) {
    return {
      'status': 'error',
      'message': 'رابط خدمة OTP غير صحيح.',
    };
  }

  final result = await _serviceQuery({'action': 'health'});
  if (result['status'] == 'healthy' && result['version'] == 'email-otp-v2') {
    return result;
  }
  return {
    'status': 'error',
    'message': result['message']?.toString() ??
        'خدمة OTP تحتاج نشر الإصدار email-otp-v2.',
  };
}

Future<Map<String, dynamic>> createGeneratorAccessRequest({
  required String requesterName,
  required String idToken,
  required String tool,
}) async {
  final health = await checkGeneratorApprovalService();
  if (health['status'] != 'healthy') return health;

  final now = DateTime.now();
  final requestId =
      'req_${now.millisecondsSinceEpoch}_${_randomHex(12)}';
  final pollToken = _randomHex(32);

  try {
    await _submitHiddenForm({
      'action': 'requestOtp',
      'requestId': requestId,
      'pollToken': pollToken,
      'requesterName': requesterName,
      'tool': tool,
      'idToken': idToken,
      'device': html.window.navigator.userAgent,
    });

    final deadline = now.add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      final status = await pollGeneratorAccessRequest(
        requestId: requestId,
        pollToken: pollToken,
      );
      final code = status['status']?.toString() ?? 'error';
      if (code == 'otp_sent') {
        return {
          'status': 'submitted',
          'requestId': requestId,
          'pollToken': pollToken,
          'expiresAt': status['expiresAt'] ??
              now.add(_otpLifetime).millisecondsSinceEpoch,
          'message': status['message'],
        };
      }
      if (code == 'pending' || code == 'invalid') {
        await Future<void>.delayed(const Duration(milliseconds: 550));
        continue;
      }
      return status;
    }

    return {
      'status': 'error',
      'message': 'لم تؤكد خدمة OTP إرسال الكود. حاول مرة أخرى.',
    };
  } on Object {
    return {
      'status': 'error',
      'message': 'تعذر إرسال طلب OTP.',
    };
  }
}

Future<Map<String, dynamic>> verifyGeneratorAccessOtp({
  required String requestId,
  required String pollToken,
  required String otp,
  required String idToken,
}) async {
  final cleanOtp = otp.trim();
  if (!RegExp(r'^\d{6}$').hasMatch(cleanOtp)) {
    return {
      'status': 'invalid_otp',
      'message': 'أدخل كودًا مكونًا من 6 أرقام.',
    };
  }

  try {
    await _submitHiddenForm({
      'action': 'verifyOtp',
      'requestId': requestId,
      'pollToken': pollToken,
      'otp': cleanOtp,
      'idToken': idToken,
    });

    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (DateTime.now().isBefore(deadline)) {
      final result = await pollGeneratorAccessRequest(
        requestId: requestId,
        pollToken: pollToken,
      );
      final status = result['status']?.toString() ?? 'error';
      if (status == 'approved' ||
          status == 'invalid_otp' ||
          status == 'expired' ||
          status == 'locked' ||
          status == 'unauthorized' ||
          status == 'error') {
        return result;
      }
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }

    return {
      'status': 'error',
      'message': 'لم تصل نتيجة التحقق من OTP.',
    };
  } on Object {
    return {
      'status': 'error',
      'message': 'تعذر التحقق من كود OTP.',
    };
  }
}

Future<Map<String, dynamic>> pollGeneratorAccessRequest({
  required String requestId,
  required String pollToken,
}) {
  return _serviceQuery({
    'action': 'poll',
    'id': requestId,
    'token': pollToken,
  });
}

// Deliberately disabled: a fresh password + OTP is required on reload.
DateTime? readGeneratorApprovalExpiry() => null;
void saveGeneratorApprovalExpiry(DateTime approvedUntil) {}
void clearGeneratorApproval() {}

Future<bool> sendGeneratorLoginEmail({
  required String username,
  required String accountEmail,
}) async => false;
