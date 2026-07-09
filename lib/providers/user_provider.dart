import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../services/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(FirebaseFirestore.instance, FirebaseAuth.instance);
});

final usersStreamProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.read(userRepositoryProvider).watchUsers();
});
