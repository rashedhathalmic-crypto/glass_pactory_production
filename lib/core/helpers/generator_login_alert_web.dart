// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

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

void showGeneratorLoginNotification() {
  try {
    if (!html.Notification.supported ||
        html.Notification.permission != 'granted') {
      return;
    }
    html.Notification(
      'Glass CNC Tools',
      body: 'تم تسجيل الدخول إلى مولد ومحاكي برامج الـNC بنجاح.',
    );
  } on Object {
    // Browser notifications are optional and must never block login.
  }
}

Future<bool> sendGeneratorLoginEmail({
  required String username,
  required String accountEmail,
}) async {
  try {
    final now = DateTime.now().toIso8601String();
    final response = await html.HttpRequest.request(
      'https://formsubmit.co/ajax/$accountEmail',
      method: 'POST',
      requestHeaders: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      sendData: jsonEncode({
        '_subject': 'Glass CNC Tools login alert',
        '_template': 'table',
        'application': 'Glass CNC Tools',
        'username': username,
        'account': accountEmail,
        'login_time': now,
        'page': html.window.location.href,
        'browser': html.window.navigator.userAgent,
        'message': 'A successful login was completed.',
      }),
    );
    return response.status != null &&
        response.status! >= 200 &&
        response.status! < 300;
  } on Object {
    return false;
  }
}
