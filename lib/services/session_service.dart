import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';

class SessionService {
  SessionService(this._ref);

  final Ref _ref;
  DateTime? _lastActivity;
  Timer? _timeoutTimer;

  void recordActivity() {
    _lastActivity = DateTime.now();
    _resetTimeout();
  }

  void _resetTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(AppConstants.sessionTimeout, () async {
      await _ref.read(authServiceProvider).signOut();
    });
  }

  bool get isExpired {
    if (_lastActivity == null) return false;
    return DateTime.now().difference(_lastActivity!) >
        AppConstants.sessionTimeout;
  }

  void dispose() {
    _timeoutTimer?.cancel();
  }
}
