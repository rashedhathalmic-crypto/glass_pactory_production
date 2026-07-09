import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../services/session_service.dart';

class SessionNotifier extends Notifier<void> {
  late SessionService _sessionService;

  @override
  void build() {
    _sessionService = SessionService(ref);
    ref.onDispose(_sessionService.dispose);

    ref.listen(
      authStateProvider.select((state) => state.asData?.value?.uid),
      (previous, next) {
        if (next != null) {
          _sessionService.recordActivity();
        }
      },
    );
  }

  void recordActivity() => _sessionService.recordActivity();
}
