import 'package:flutter/foundation.dart';

import '../models/app_user.dart';

/// Handles authentication and holds the signed-in user (RBAC source of truth).
///
/// Firebase seam: replace [login]/[logout] with FirebaseAuth calls and load the
/// role/branch from the user's Firestore `users` document.
class AuthController extends ChangeNotifier {
  final List<AppUser> _users = [
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
  ];

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  String? _error;
  String? get error => _error;

  List<AppUser> get users => List.unmodifiable(_users);

  /// Attempts sign-in with username + password. Returns true on success.
  bool login(String username, String password) {
    final match = _users.where((u) =>
        u.username.toLowerCase() == username.trim().toLowerCase() &&
        u.password == password);
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

  // --- Admin user management ---------------------------------------------
  void addUser(AppUser user) {
    _users.add(user);
    notifyListeners();
  }

  void toggleActive(String id) {
    for (final u in _users) {
      if (u.id == id) {
        u.isActive = !u.isActive;
        notifyListeners();
        return;
      }
    }
  }

  String newUserId() => 'u${DateTime.now().millisecondsSinceEpoch}';
}
