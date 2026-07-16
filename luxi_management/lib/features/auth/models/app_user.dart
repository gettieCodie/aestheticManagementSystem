/// The two authenticated roles. Owner is represented by [admin].
enum UserRole {
  admin('Admin'),
  staff('Staff');

  const UserRole(this.label);
  final String label;
}

/// A user account. In production this maps to a Firebase Auth user plus a
/// `users` document; the plaintext [password] here is mock-only — real auth
/// never stores passwords (Firebase handles hashing).
class AppUser {
  AppUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    required this.password,
    required this.role,
    this.branch,
    this.isActive = true,
  });

  final String id;
  final String fullName;
  final String username;
  final String email;
  final String password;
  final UserRole role;

  /// Assigned branch for staff (null for admin, who spans all branches).
  final String? branch;
  bool isActive;

  bool get isAdmin => role == UserRole.admin;
}
