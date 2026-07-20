import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/firestore/branch_lookup.dart';
import '../../../core/firestore/firestore_dates.dart';
import '../models/appointment.dart';

/// Firestore-backed source of truth for the `bookings` collection — the same
/// collection the client-facing `luxi_appointment` app writes to. Staff
/// actions here (confirm, check-in, complete, reschedule, cancel, no-show,
/// walk-in booking) are real writes to that collection, and clients' own
/// bookings show up here live via [watchAppointments].
///
/// `booking_NN` ids are allocated from the same `meta/counters.bookingSeq`
/// counter `luxi_appointment` uses, so ids stay unique and sequential no
/// matter which app creates the booking.
///
/// Note: customer/package/billing data is intentionally NOT synced here —
/// only appointments/bookings. [Appointment.customerId] on a booking made by
/// a client may not match any locally-known [Customer]; that's expected.
class AppointmentsRepository {
  AppointmentsRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  static const Map<AppointmentStatus, String> _statusOut = {
    AppointmentStatus.pending: 'pending',
    AppointmentStatus.confirmed: 'confirmed',
    AppointmentStatus.arrived: 'arrived',
    AppointmentStatus.completed: 'completed',
    AppointmentStatus.cancelled: 'cancelled',
    AppointmentStatus.noShow: 'no_show',
  };

  static final Map<String, AppointmentStatus> _statusIn = {
    for (final entry in _statusOut.entries) entry.value: entry.key,
  };

  /// Live view of every booking, mapped to [Appointment]. Firestore's local
  /// cache reflects a write immediately (before the server round-trip), so
  /// UI driven by this stream still feels instant after a staff action.
  Stream<List<Appointment>> watchAppointments() {
    return _db.collection('bookings').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => _fromDoc(doc.id, doc.data()))
              .toList(),
        );
  }

  Appointment _fromDoc(String id, Map<String, dynamic> data) {
    final dateStr = data['appointmentDate'] as String?;
    final date = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();
    final branchId = data['branchId'] as String?;

    return Appointment(
      id: id,
      customerId: data['customerId'] as String?,
      phone: data['phone'] as String?,
      customerName: data['customerName'] as String? ?? '',
      serviceName: data['serviceName'] as String? ?? '',
      branch: BranchLookup.shortNameById[branchId] ??
          data['branchName'] as String? ??
          '',
      date: DateTime(date.year, date.month, date.day),
      time: to12Hour(data['appointmentTime'] as String? ?? '09:00'),
      status:
          _statusIn[data['status'] as String?] ?? AppointmentStatus.pending,
      packageId: data['packageId'] as String?,
      packageName: data['packageName'] as String?,
      sessionNumber: (data['sessionNumber'] as num?)?.toInt(),
      cancelReason: data['cancelReason'] as String?,
      lastContactedAt: (data['lastContactedAt'] as Timestamp?)?.toDate(),
      productsUsed:
          (data['productsUsed'] as List?)?.cast<String>() ?? const [],
      notes: data['notes'] as String? ?? '',
      photoCount: (data['photoCount'] as num?)?.toInt() ?? 0,
      progressPhotos:
          (data['progressPhotos'] as List?)?.cast<String>() ?? const [],
      isSensitive: data['isSensitive'] as bool? ?? false,
      staffName: data['staffName'] as String? ?? '',
    );
  }

  /// Creates a new booking (walk-in, staff-scheduled, or a package session)
  /// and returns its `booking_NN` id.
  Future<String> createAppointment({
    required String customerName,
    String? customerId,
    String? phone,
    required String serviceName,
    required String branchShortName,
    required DateTime date,
    required String time12h,
    AppointmentStatus status = AppointmentStatus.confirmed,
    String? packageId,
    String? packageName,
    int? sessionNumber,
    double? servicePrice,
    int durationMinutes = 30,
  }) async {
    final id = await _nextBookingId();
    final branchId = BranchLookup.idByShortName[branchShortName];
    final day = DateTime(date.year, date.month, date.day);
    final time24 = to24Hour(time12h);

    await _db.collection('bookings').doc(id).set({
      'customerId': customerId,
      'customerName': customerName,
      'phone': phone,
      'serviceName': serviceName,
      'servicePrice': servicePrice,
      'branchId': branchId,
      'branchName': branchId != null
          ? BranchLookup.fullNameById[branchId]
          : branchShortName,
      'appointmentDate': FirestoreDates.dateOnly(day),
      'appointmentTime': time24,
      'startAt': Timestamp.fromDate(_combine(day, time24)),
      'durationMinutes': durationMinutes,
      'status': _statusOut[status],
      'assessedPrice': null,
      'assignedStaffId': null,
      'staffName': '',
      'packageId': packageId,
      'packageName': packageName,
      'sessionNumber': sessionNumber,
      'productsUsed': <String>[],
      'progressPhotos': <String>[],
      'notes': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  Future<void> confirm(String id) => _setStatus(id, AppointmentStatus.confirmed);
  Future<void> checkIn(String id) => _setStatus(id, AppointmentStatus.arrived);
  Future<void> markNoShow(String id) => _setStatus(id, AppointmentStatus.noShow);

  Future<void> _setStatus(String id, AppointmentStatus status) =>
      _update(id, {'status': _statusOut[status]});

  Future<void> logContact(String id) =>
      _update(id, {'lastContactedAt': FieldValue.serverTimestamp()});

  /// Backfills a walk-in booking's `customerId` once it's been matched to a
  /// (possibly just-created) customer record — without this, a walk-in's
  /// completed session never attributes back to that customer, so their
  /// session history looks empty even though they have a balance/sale on
  /// record.
  Future<void> setCustomerId(String id, String customerId) =>
      _update(id, {'customerId': customerId});

  Future<void> cancel(String id, String reason) => _update(id, {
        'status': _statusOut[AppointmentStatus.cancelled],
        'cancelReason': reason,
      });

  Future<void> reschedule(String id, DateTime date, String time12h) {
    final day = DateTime(date.year, date.month, date.day);
    final time24 = to24Hour(time12h);
    return _update(id, {
      'appointmentDate': FirestoreDates.dateOnly(day),
      'appointmentTime': time24,
      'startAt': Timestamp.fromDate(_combine(day, time24)),
    });
  }

  Future<void> complete(
    String id, {
    required List<String> productsUsed,
    required String notes,
    required List<String> progressPhotos,
    required bool isSensitive,
    required String staffName,
  }) =>
      _update(id, {
        'status': _statusOut[AppointmentStatus.completed],
        'productsUsed': productsUsed,
        'notes': notes,
        'photoCount': progressPhotos.length,
        'progressPhotos': progressPhotos,
        'isSensitive': isSensitive,
        'staffName': staffName,
      });

  /// Uploads a treatment progress photo to Cloud Storage under
  /// `treatment_photos/` and returns its download URL.
  Future<String> uploadTreatmentPhoto(Uint8List bytes, String fileName) async {
    final ref = _storage
        .ref()
        .child('treatment_photos')
        .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');
    await ref.putData(bytes);
    return ref.getDownloadURL();
  }

  Future<void> _update(String id, Map<String, dynamic> fields) {
    return _db.collection('bookings').doc(id).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Atomically allocates the next `booking_NN` id from the counter shared
  /// with `luxi_appointment`'s `BookingDataService`.
  Future<String> _nextBookingId() async {
    final counterRef = _db.collection('meta').doc('counters');
    return _db.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final current = (snapshot.data()?['bookingSeq'] as num?)?.toInt() ?? 0;
      final next = current + 1;
      transaction.set(
        counterRef,
        {'bookingSeq': next},
        SetOptions(merge: true),
      );
      return 'booking_${next.toString().padLeft(2, '0')}';
    });
  }

  static DateTime _combine(DateTime day, String time24) {
    final parts = time24.split(':');
    return DateTime(
      day.year,
      day.month,
      day.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  /// `9:00 AM` -> `09:00` (matches [kTimeSlots] in scheduling_page.dart).
  static String to24Hour(String time12) {
    final parts = time12.trim().split(' ');
    final hm = parts[0].split(':');
    int hour = int.parse(hm[0]);
    final minute = hm[1];
    final period = parts.length > 1 ? parts[1].toUpperCase() : 'AM';
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return '${hour.toString().padLeft(2, '0')}:$minute';
  }

  /// `09:00` -> `9:00 AM` (matches the Firestore `appointmentTime` format).
  static String to12Hour(String time24) {
    final hm = time24.split(':');
    final hour = int.parse(hm[0]);
    final minute = hm[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    var hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;
    return '$hour12:$minute $period';
  }
}
