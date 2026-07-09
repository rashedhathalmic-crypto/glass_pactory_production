import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'user_provider.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    FirebaseAuth.instance,
    ref.read(userRepositoryProvider),
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.read(authServiceProvider).authStateChanges();
});

/// Loads the signed-in profile once per auth uid.
/// Uses [select] so token refreshes do not trigger a refetch.
final currentAppUserProvider = FutureProvider<AppUser?>((ref) async {
  final uid = ref.watch(
    authStateProvider.select((state) => state.asData?.value?.uid),
  );
  if (uid == null) return null;
  return ref.read(userRepositoryProvider).getUser(uid);
});
