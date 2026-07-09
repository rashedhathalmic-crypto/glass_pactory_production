import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/firestore_constants.dart';
import '../models/app_user.dart';
import '../models/enums/department.dart';
import '../models/enums/user_role.dart';
import '../utils/exceptions/exceptions.dart';

class UserRepository {
  UserRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection(FirestoreConstants.users);

  Future<AppUser?> getUser(String uid) async {
    try {
      final doc = await _usersRef.doc(uid).get();
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to load user',
        code: e.code,
      );
    }
  }

  Stream<List<AppUser>> watchUsers() {
    return _usersRef
        .orderBy('displayName')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AppUser.fromFirestore).toList());
  }

  Future<List<AppUser>> getUsersByDepartment(String departmentName) async {
    final snapshot = await _usersRef
        .where('department', isEqualTo: departmentName)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map(AppUser.fromFirestore).toList();
  }

  Future<List<AppUser>> getOperatorsForDepartment(String departmentName) async {
    final snapshot = await _usersRef
        .where(
          'role',
          whereIn: [
            UserRole.operator.name,
            UserRole.supervisor.name,
            UserRole.qualityInspector.name,
          ],
        )
        .where('department', isEqualTo: departmentName)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map(AppUser.fromFirestore).toList();
  }

  Future<int> countActiveUsers() async {
    final snapshot = await _usersRef
        .where('isActive', isEqualTo: true)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<void> createUser({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? department,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;
      final now = DateTime.now();

      final user = AppUser(
        uid: uid,
        email: email.trim(),
        displayName: displayName.trim(),
        role: role,
        department: department != null
            ? Department.fromString(department)
            : null,
        createdAt: now,
        updatedAt: now,
      );

      await _usersRef.doc(uid).set(user.toMap());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapCreateUserError(e.code), code: e.code);
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to create user',
        code: e.code,
      );
    }
  }

  Future<void> updateUser(AppUser user) async {
    try {
      await _usersRef.doc(user.uid).update({
        ...user.copyWith(updatedAt: DateTime.now()).toMap(),
      });
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to update user',
        code: e.code,
      );
    }
  }

  Future<void> setUserActiveStatus(String uid, bool isActive) async {
    try {
      await _usersRef.doc(uid).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to update user status',
        code: e.code,
      );
    }
  }

  Future<void> updateLastLogin(String uid) async {
    await _usersRef.doc(uid).update({
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  String _mapCreateUserError(String code) {
    return switch (code) {
      'email-already-in-use' => 'An account with this email already exists',
      'weak-password' => 'Password is too weak',
      'invalid-email' => 'Invalid email address',
      _ => 'Failed to create user account',
    };
  }
}
