import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_notifier.dart';

final sessionProvider = NotifierProvider<SessionNotifier, void>(
  SessionNotifier.new,
);
