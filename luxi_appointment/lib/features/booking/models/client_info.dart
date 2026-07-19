import 'package:flutter/foundation.dart';

/// Client-supplied contact details captured in step 3.
///
/// [photoPath] is an optional Cloud Storage download URL for the client's
/// profile photo, set only after [UploadProfileWidget] finishes uploading it
/// — see `BookingDataService.uploadClientPhoto`.
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
