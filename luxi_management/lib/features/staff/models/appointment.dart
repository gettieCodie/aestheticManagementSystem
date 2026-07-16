import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum AppointmentStatus {
  pending('Pending', AppColors.warning),
  confirmed('Confirmed', AppColors.primary),
  arrived('Arrived', AppColors.secondary),
  completed('Completed', AppColors.success),
  cancelled('Cancelled', AppColors.textSecondary),
  noShow('No-show', AppColors.error);

  const AppointmentStatus(this.label, this.color);
  final String label;
  final Color color;
}

/// A scheduled appointment (walk-in or a package session).
///
/// Mutable status/date/time and the treatment-record fields let the store move
/// an appointment through its lifecycle in place.
class Appointment {
  Appointment({
    required this.id,
    required this.customerName,
    required this.serviceName,
    required this.branch,
    required this.date,
    required this.time,
    required this.status,
    this.customerId,
    this.phone,
    this.packageId,
    this.packageName,
    this.sessionNumber,
    this.cancelReason,
    this.lastContactedAt,
    List<String>? productsUsed,
    this.notes = '',
    this.photoCount = 0,
    this.isSensitive = false,
  }) : productsUsed = productsUsed ?? [];

  final String id;
  final String? customerId;
  final String? phone;
  final String customerName;
  final String serviceName;
  final String branch;

  // Mutable across the lifecycle.
  DateTime date;
  String time;
  AppointmentStatus status;

  final String? packageId;
  final String? packageName;
  final int? sessionNumber;

  // Cancellation / contact tracking.
  String? cancelReason;
  DateTime? lastContactedAt;

  // Treatment record (filled on Complete).
  List<String> productsUsed;
  String notes;
  int photoCount;
  bool isSensitive;

  bool get isPackageSession => packageName != null;

  /// A label that never renders "undefined": "Skin Rejuvenation (Session 4 of 6)".
  String sessionLabel(int? totalSessions) {
    if (!isPackageSession) return serviceName;
    if (sessionNumber != null && totalSessions != null) {
      return '$serviceName (Session $sessionNumber of $totalSessions)';
    }
    if (sessionNumber != null) return '$serviceName · Session $sessionNumber';
    return serviceName;
  }

  bool get isOpen =>
      status == AppointmentStatus.pending ||
      status == AppointmentStatus.confirmed ||
      status == AppointmentStatus.arrived;
}
