import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/firestore/store_errors.dart';
import '../models/app_user.dart';
import '../services/users_repository.dart';

/// Handles authentication and holds the signed-in user (RBAC source of truth).
///
/// [login] checks two candidate lists: a small hardcoded [_credentials] set
/// (the built-in demo accounts, so they keep working even before Firestore
/// has any `users` docs) and the live [_users] list synced from Firestore's
/// `users` collection via [UsersRepository] — so accounts created in User
/// Management can log in with the password they were given there. This is a
/// demo-appropriate stand-in; production should replace it with real
/// Firebase Auth, which never stores passwords client-side.
class AuthController extends ChangeNotifier with FirestoreErrorTracker {
  AuthController({UsersRepository? usersRepository})
      : _usersRepo = usersRepository ?? UsersRepository() {
    _usersSub = _usersRepo.watchUsers().listen((list) {
      clearStreamError('users');
      _users = list;
      _reconcileCurrentUser();
      notifyListeners();
    }, onError: (Object e) => reportStreamError('users', e));
  }

  /// Keeps the signed-in session honest against the live `users` list —
  /// without this, deactivating (or deleting, or re-scoping the role/branch
  /// of) an account someone is currently signed in as had no effect until
  /// they voluntarily logged out, so the old permissions kept working.
  void _reconcileCurrentUser() {
    final current = _currentUser;
    if (current == null) return;
    // Built-in demo accounts aren't Firestore-backed — nothing to reconcile.
    if (_credentials.any((c) => c.id == current.id)) return;

    for (final u in _users) {
      if (u.id == current.id) {
        if (!u.isActive) {
          _currentUser = null;
          _error = 'This account has been deactivated.';
        } else {
          _currentUser = u;
        }
        return;
      }
    }
    // The account no longer exists in the live list at all.
    _currentUser = null;
  }

  final UsersRepository _usersRepo;
  late final StreamSubscription<List<AppUser>> _usersSub;

  @override
  void dispose() {
    _usersSub.cancel();
    super.dispose();
  }

  /// Built-in demo accounts — checked alongside the live Firestore [_users]
  /// list in [login]. See class doc.
  final List<AppUser> _credentials = [
    AppUser(id: 'u_admin', fullName: 'Owner Admin', username: 'admin',
        email: 'owner@luxuriskin.com', password: 'admin123', role: UserRole.admin),
    // Laguna
    AppUser(id: 'u1', fullName: 'Angela Cruz', username: 'angela',
        email: 'angela@luxuriskin.com', password: 'staff123', role: UserRole.staff, branch: 'Laguna'),
    AppUser(id: 'u2', fullName: 'Elena Garcia', username: 'elena',
        email: 'elena@luxuriskin.com', password: 'staff123', role: UserRole.staff, branch: 'Laguna'),
    // Batangas
    AppUser(id: 'u3', fullName: 'Isabel Fernandez', username: 'isabel',
        email: 'isabel@luxuriskin.com', password: 'staff123', role: UserRole.staff, branch: 'Batangas'),
    AppUser(id: 'u4', fullName: 'Carmen Reyes', username: 'carmen',
        email: 'carmen@luxuriskin.com', password: 'staff123', role: UserRole.staff, branch: 'Batangas'),
    // Lipa
    AppUser(id: 'u5', fullName: 'Sofia Torres', username: 'sofia',
        email: 'sofia@luxuriskin.com', password: 'staff123', role: UserRole.staff, branch: 'Lipa'),
    AppUser(id: 'u6', fullName: 'Liza Tan', username: 'liza',
        email: 'liza@luxuriskin.com', password: 'staff123', role: UserRole.staff, branch: 'Lipa'),
    // Pampanga
    AppUser(id: 'u7', fullName: 'Miguel Santos', username: 'miguel',
        email: 'miguel@luxuriskin.com', password: 'staff123', role: UserRole.staff, branch: 'Pampanga'),
    AppUser(id: 'u8', fullName: 'Rafael Cruz', username: 'rafael',
        email: 'rafael@luxuriskin.com', password: 'staff123', role: UserRole.staff, branch: 'Pampanga'),
    // One extra account per branch, matching luxi_appointment's seeded
    // Firestore `users` docs — logs in with the FULL email as the username
    // (not a short handle), so it doubles as a check that email-as-username
    // sign-in works.
    AppUser(id: 'u9', fullName: 'Angela Reyes', username: 'angela.reyes@luxuriskin.ph',
        email: 'angela.reyes@luxuriskin.ph', password: 'staff123', role: UserRole.staff, branch: 'Laguna'),
    AppUser(id: 'u10', fullName: 'Carlo Villanueva', username: 'carlo.villanueva@luxuriskin.ph',
        email: 'carlo.villanueva@luxuriskin.ph', password: 'staff123', role: UserRole.staff, branch: 'Lipa'),
    AppUser(id: 'u11', fullName: 'Diane Mercado', username: 'diane.mercado@luxuriskin.ph',
        email: 'diane.mercado@luxuriskin.ph', password: 'staff123', role: UserRole.staff, branch: 'Batangas'),
    AppUser(id: 'u12', fullName: 'Michael Torres', username: 'michael.torres@luxuriskin.ph',
        email: 'michael.torres@luxuriskin.ph', password: 'staff123', role: UserRole.staff, branch: 'Pampanga'),
  ];

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  String? _error;
  String? get error => _error;

  /// Live from Firestore's `users` collection — feeds both User Management's
  /// list and [login]. See class doc.
  List<AppUser> _users = [];
  List<AppUser> get users => List.unmodifiable(_users);

  /// Attempts sign-in with username + password against [_credentials] and
  /// the live Firestore-backed [_users] list. Returns true on success.
  bool login(String username, String password) {
    final normalized = username.trim().toLowerCase();
    final match = [..._credentials, ..._users].where((u) =>
        u.username.toLowerCase() == normalized && u.password == password);
    if (match.isEmpty) {
      _error = 'Invalid username or password.';
      notifyListeners();
      return false;
    }
    final user = match.first;
    if (!user.isActive) {
      _error = 'This account has been deactivated.';
      notifyListeners();
      return false;
    }
    _currentUser = user;
    _error = null;
    notifyListeners();
    return true;
  }

  void logout() {
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  // --- Admin user management -----------------------------------------------
  // Writes to Firestore's `users` collection — updates [users] (and hence
  // login candidates) once the live stream picks it up.
  Future<void> addUser(AppUser user) => _usersRepo.addUser(user);

  Future<void> toggleActive(String id) {
    final current = _users.where((u) => u.id == id);
    if (current.isEmpty) return Future.value();
    return _usersRepo.toggleActive(id, !current.first.isActive);
  }

  /// Placeholder id for a brand-new [AppUser] before it's saved — the
  /// repository mints the real `user_NN` id on [addUser].
  String newUserId() => 'u${DateTime.now().millisecondsSinceEpoch}';
}
