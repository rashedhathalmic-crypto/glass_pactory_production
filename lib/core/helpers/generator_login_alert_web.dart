// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';

const _approvalServiceUrl =
    'https://script.google.com/macros/s/'
    'AKfycbxwidW-HceCIzOnF8jNx3Ewl5tkKvtjHDRNni75mbGi/exec';
const _approvalUntilKey = 'glass_cnc_access_approved_until';

Future<bool> requestGeneratorNotificationPermission() async {
  try {
    if (!html.Notification.supported) return false;
    if (html.Notification.permission == 'granted') return true;
    final permission = await html.Notification.requestPermission();
    return permission == 'granted';
  } on Object {
    return false;
  }
}

void showGeneratorLoginNotification({
  required String title,
  required String body,
}) {
  try {
    if (!html.Notification.supported ||
        html.Notification.permission != 'granted') {
      return;
    }
    html.Notification(title, body: body);
  } on Object {
    // Notifications are optional and must never block approved access.
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

void _addHiddenField(
  html.FormElement form,
  String name,
  String value,
) {
  final input = html.InputElement()
    ..type = 'hidden'
    ..name = name
    ..value = value;
  form.children.add(input);
}

Future<Map<String, dynamic>> createGeneratorAccessRequest({
  required String requesterName,
  required String idToken,
  required String tool,
}) async {
  final body = html.document.body;
  if (body == null) {
    return {
      'status': 'error',
      'message': 'تعذر فتح خدمة الموافقة في المتصفح.',
    };
  }

  final now = DateTime.now();
  final requestId =
      'req_${now.millisecondsSinceEpoch}_${_randomHex(12)}';
  final pollToken = _randomHex(32);
  final frameName =
      'glass_cnc_access_${now.microsecondsSinceEpoch}_${_randomHex(4)}';

  final iframe = html.IFrameElement()
    ..name = frameName
    ..style.display = 'none';
  final form = html.FormElement()
    ..method = 'POST'
    ..action = _approvalServiceUrl
    ..target = frameName
    ..style.display = 'none';

  _addHiddenField(form, 'action', 'request');
  _addHiddenField(form, 'requestId', requestId);
  _addHiddenField(form, 'pollToken', pollToken);
  _addHiddenField(form, 'requesterName', requesterName);
  _addHiddenField(form, 'tool', tool);
  _addHiddenField(form, 'idToken', idToken);
  _addHiddenField(
    form,
    'device',
    html.window.navigator.userAgent,
  );

  body.children.add(iframe);
  body.children.add(form);

  try {
    form.submit();
    // Cross-origin form submission cannot expose the response to Dart.
    // Polling below verifies that the server accepted and stored the request.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    return {
      'status': 'submitted',
      'requestId': requestId,
      'pollToken': pollToken,
      'expiresAt': now
          .add(const Duration(minutes: 10))
          .millisecondsSinceEpoch,
    };
  } on Object {
    return {
      'status': 'error',
      'message': 'تعذر إرسال طلب الموافقة.',
    };
  } finally {
    form.remove();
    iframe.remove();
  }
}

Future<Map<String, dynamic>> pollGeneratorAccessRequest({
  required String requestId,
  required String pollToken,
}) async {
  final body = html.document.body;
  if (body == null) {
    return {
      'status': 'error',
      'message': 'تعذر قراءة حالة طلب الموافقة.',
    };
  }

  final storageKey =
      'glass_cnc_poll_${DateTime.now().microsecondsSinceEpoch}_'
      '${_randomHex(4)}';
  html.window.localStorage.remove(storageKey);

  final uri = Uri.parse(_approvalServiceUrl).replace(
    queryParameters: {
      'action': 'poll',
      'id': requestId,
      'token': pollToken,
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
      loaded.completeError(
        StateError('Approval polling script failed to load'),
      );
    }
  });

  body.children.add(script);

  try {
    await loaded.future.timeout(const Duration(seconds: 12));
    final raw = html.window.localStorage[storageKey];
    if (raw == null || raw.isEmpty) {
      return {'status': 'invalid'};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return {
        'status': 'error',
        'message': 'استجابة خدمة الموافقة غير صحيحة.',
      };
    }

    final result = Map<String, dynamic>.from(decoded);
    final status = result['status']?.toString() ?? 'error';
    return {
      ...result,
      'status': status,
    };
  } on TimeoutException {
    return {
      'status': 'error',
      'message': 'انتهت مهلة الاتصال بخدمة الموافقة.',
    };
  } on Object {
    return {
      'status': 'error',
      'message': 'تعذر الاتصال بخدمة الموافقة.',
    };
  } finally {
    await loadSubscription.cancel();
    await errorSubscription.cancel();
    script.remove();
    html.window.localStorage.remove(storageKey);
  }
}

DateTime? readGeneratorApprovalExpiry() {
  try {
    final raw = html.window.localStorage[_approvalUntilKey];
    final milliseconds = int.tryParse(raw ?? '');
    if (milliseconds == null) return null;

    final approvedUntil =
        DateTime.fromMillisecondsSinceEpoch(milliseconds);
    if (!approvedUntil.isAfter(DateTime.now())) {
      clearGeneratorApproval();
      return null;
    }
    return approvedUntil;
  } on Object {
    return null;
  }
}

void saveGeneratorApprovalExpiry(DateTime approvedUntil) {
  try {
    html.window.localStorage[_approvalUntilKey] =
        approvedUntil.millisecondsSinceEpoch.toString();
  } on Object {
    // If storage is blocked, approval remains valid for the current session.
  }
}

void clearGeneratorApproval() {
  try {
    html.window.localStorage.remove(_approvalUntilKey);
  } on Object {
    // Ignore unavailable browser storage.
  }
}

Future<bool> sendGeneratorLoginEmail({
  required String username,
  required String accountEmail,
}) async {
  return false;
}
