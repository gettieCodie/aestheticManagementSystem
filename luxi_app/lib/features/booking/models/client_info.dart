import 'package:flutter/foundation.dart';

/// Client-supplied contact details captured in step 3.
///
/// [photoPath] is an optional local reference to a selected profile photo. It
/// stays a plain string so a real image picker / upload service can populate it
/// later without changing consumers.
@immutable
class ClientInfo {
  const ClientInfo({
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.facebook = '',
    this.photoPath,
  });

  final String fullName;
  final String email;
  final String phone;
  final String facebook;
  final String? photoPath;

  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  bool get isComplete =>
      fullName.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      phone.trim().isNotEmpty &&
      facebook.trim().isNotEmpty;

  ClientInfo copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? facebook,
    String? photoPath,
    bool clearPhoto = false,
  }) {
    return ClientInfo(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      facebook: facebook ?? this.facebook,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    );
  }
}
