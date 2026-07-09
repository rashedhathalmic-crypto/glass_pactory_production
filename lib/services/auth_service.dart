import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../utils/exceptions/exceptions.dart';
import 'user_repository.dart';

class AuthService {
  AuthService(this._auth, this._userRepository);

  final FirebaseAuth _auth;
  final UserRepository _userRepository;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        throw const AuthException('Authentication failed');
      }

      final appUser = await _userRepository.getUser(uid);
      if (appUser == null) {
        await _auth.signOut();
        throw const AuthException('User profile not found');
      }

      if (!appUser.isActive) {
        await _auth.signOut();
        throw const AuthException(
          'Account is deactivated. Contact administrator.',
        );
      }

      await _userRepository.updateLastLogin(uid);
      return appUser;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e.code), code: e.code);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<AppUser?> getCurrentAppUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _userRepository.getUser(uid);
  }

  String _mapAuthError(String code) {
    return switch (code) {
      'user-not-found' => 'No account found with this email',
      'wrong-password' => 'Incorrect password',
      'invalid-email' => 'Invalid email address',
      'user-disabled' => 'This account has been disabled',
      'too-many-requests' => 'Too many attempts. Try again later',
      'invalid-credential' => 'Invalid email or password',
      _ => 'Authentication failed. Please try again',
    };
  }
}
