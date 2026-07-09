import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

/// Notifies [GoRouter] to re-run redirect when auth uid changes.
class RouterRefresh extends ChangeNotifier {
  RouterRefresh(this._ref) {
    _ref.listen(
      authStateProvider.select((state) => state.asData?.value?.uid),
      (_, _) => notifyListeners(),
    );
  }

  final Ref _ref;
}
