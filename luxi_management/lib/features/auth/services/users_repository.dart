import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/branch_lookup.dart';
import '../../../core/firestore/sequential_id.dart';
import '../models/app_user.dart';

/// Firestore-backed source of truth for the `users` collection, and (via the
/// `password` field) for login itself — see [AuthController.login]. Storing
/// a plaintext password in Firestore is a demo-only stand-in for real auth;
/// production should replace this with Firebase Auth, which never stores
/// passwords client-side.
class UsersRepository {
  UsersRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance,
        _ids = SequentialIdAllocator(firestore ?? FirebaseFirestore.instance);

  final FirebaseFirestore _db;
  final SequentialIdAllocator _ids;

  Stream<List<AppUser>> watchUsers() {
    return _db.collection('users').snapshots().map(
          (snap) =>
              snap.docs.map((doc) => _fromDoc(doc.id, doc.data())).toList(),
        );
  }

  AppUser _fromDoc(String id, Map<String, dynamic> data) {
    final branchId = data['branchId'] as String?;
    final email = data['email'] as String? ?? '';
    return AppUser(
      id: id,
      fullName: data['fullName'] as String? ?? '',
      // Not a real login field — the schema has no username, so this is
      // derived purely for display in the accounts table.
      username: data['username'] as String? ?? email.split('@').first,
      email: email,
      password: data['password'] as String? ?? '',
      role: (data['role'] as String?) == 'admin' ? UserRole.admin : UserRole.staff,
      branch: branchId == null ? null : BranchLookup.shortNameById[branchId],
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Future<void> addUser(AppUser user) async {
    final id = await _ids.next(
        counterField: 'userSeq', prefix: 'user_', collection: 'users');
    final branchId =
        user.branch == null ? null : BranchLookup.idByShortName[user.branch];
    await _db.collection('users').doc(id).set({
      'fullName': user.fullName,
      'username': user.username,
      'email': user.email,
      'password': user.password,
      'role': user.role == UserRole.admin ? 'admin' : 'staff',
      'branchId': branchId,
      'isActive': user.isActive,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleActive(String id, bool isActive) {
    return _db.collection('users').doc(id).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
