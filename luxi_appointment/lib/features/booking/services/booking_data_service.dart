import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../models/branch_model.dart';
import '../models/client_info.dart';
import '../models/service_category.dart';
import '../models/service_model.dart';

/// The single data seam for the booking flow — backed by Cloud Firestore
/// (and Cloud Storage for the client photo upload).
///
/// Collections read/written here follow `luxi_firestore_schema`:
/// `branches`, `services`, `customers` and `bookings`. Keep the method
/// signatures stable so the rest of the app never needs to know it's talking
/// to Firestore.
class BookingDataService {
  BookingDataService({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  /// Icon shown per service `category` field. Falls back to a generic icon
  /// for any category not listed here.
  static const Map<String, IconData> _categoryIcons = {
    'Facial': Icons.spa_rounded,
    'Body': Icons.self_improvement_rounded,
    'Laser': Icons.auto_awesome_rounded,
    'Injectables': Icons.vaccines_rounded,
  };

  static IconData _iconForCategory(String category) =>
      _categoryIcons[category] ?? Icons.star_rounded;

  /// Reads the `services` collection and groups active services by their
  /// `category` field.
  Future<List<ServiceCategory>> fetchServiceCategories() async {
    final snapshot = await _db
        .collection('services')
        .where('isActive', isEqualTo: true)
        .get();

    final byCategory = <String, List<ServiceModel>>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final category = data['category'] as String? ?? 'Other';
      final service = ServiceModel.fromMap(
        doc.id,
        data,
        icon: _iconForCategory(category),
      );
      byCategory.putIfAbsent(category, () => []).add(service);
    }

    final categories = byCategory.entries
        .map(
          (entry) => ServiceCategory(
            id: entry.key.toLowerCase(),
            title: entry.key,
            icon: _iconForCategory(entry.key),
            services: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return categories;
  }

  /// Reads the `branches` collection.
  ///
  /// Sorted client-side (rather than an Firestore `orderBy`) so this doesn't
  /// need a composite index alongside the `isActive` filter.
  Future<List<BranchModel>> fetchBranches() async {
    final snapshot = await _db
        .collection('branches')
        .where('isActive', isEqualTo: true)
        .get();
    final branches = snapshot.docs
        .map((doc) => BranchModel.fromMap(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return branches;
  }

  /// Bookable time slots generated from clinic hours (client-side), minus
  /// any slot that's already at [AppConstants.branchCapacity] for the given
  /// branch/date — so two clients can't both book the last open chair.
  ///
  /// When [branchId] or [date] isn't chosen yet, returns the full clinic-hours
  /// list unfiltered (there's nothing to check availability against yet).
  Future<List<TimeOfDay>> fetchTimeSlots({String? branchId, DateTime? date}) async {
    final slots = <TimeOfDay>[];
    int minutes = AppConstants.openingHour * 60;
    final int end = AppConstants.closingHour * 60;
    while (minutes <= end) {
      slots.add(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
      minutes += AppConstants.slotMinutes;
    }

    if (branchId == null || date == null) return slots;

    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final existing = await _db
        .collection('bookings')
        .where('branchId', isEqualTo: branchId)
        .where('appointmentDate', isEqualTo: dateStr)
        .get();

    final counts = <String, int>{};
    for (final doc in existing.docs) {
      final status = doc.data()['status'] as String?;
      if (status == 'cancelled' || status == 'no_show') continue;
      final time = doc.data()['appointmentTime'] as String?;
      if (time == null) continue;
      counts[time] = (counts[time] ?? 0) + 1;
    }

    return slots.where((slot) {
      final key = '${slot.hour.toString().padLeft(2, '0')}:'
          '${slot.minute.toString().padLeft(2, '0')}';
      return (counts[key] ?? 0) < AppConstants.branchCapacity;
    }).toList();
  }

  /// Uploads a client-submitted profile photo to Cloud Storage under
  /// `client_photos/` and returns its public download URL, ready to persist
  /// on the booking doc via [createBooking].
  Future<String> uploadClientPhoto(Uint8List bytes, String fileName) async {
    final ref = _storage
        .ref()
        .child('client_photos')
        .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');
    await ref.putData(bytes);
    return ref.getDownloadURL();
  }

  /// Creates a booking, matching or creating the `customers` record by phone.
  ///
  /// [client]'s `photoPath`, if set, is expected to already be a Cloud
  /// Storage download URL (see [uploadClientPhoto]) — it's stored as-is in
  /// `progressPhotos`.
  Future<void> createBooking({
    required ServiceModel service,
    required BranchModel branch,
    required DateTime date,
    required TimeOfDay time,
    required ClientInfo client,
  }) async {
    final customerId = await _findOrCreateCustomer(client);
    final bookingId = await _nextSequentialId(
      counterField: 'bookingSeq',
      prefix: 'booking_',
    );

    final appointmentDate =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final appointmentTime =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    final startAt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);

    await _db.collection('bookings').doc(bookingId).set({
      'customerId': customerId,
      'customerName': client.fullName.trim(),
      'phone': client.phone.trim(),
      'serviceId': service.id,
      'serviceName': service.name,
      'servicePrice': service.price,
      'branchId': branch.id,
      'branchName': branch.name,
      'appointmentDate': appointmentDate,
      'appointmentTime': appointmentTime,
      'startAt': Timestamp.fromDate(startAt),
      'durationMinutes': service.durationMinutes,
      'status': 'pending',
      'assessedPrice': null,
      'assignedStaffId': null,
      'staffName': '',
      'productsUsed': <String>[],
      'progressPhotos': client.photoPath == null || client.photoPath!.isEmpty
          ? <String>[]
          : [client.photoPath],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Atomically allocates the next `{prefix}NN` id for some entity, using a
  /// counter field on `meta/counters` (seeded to the highest existing id by
  /// [FirestoreSeeder]). Using a transaction means two callers racing at the
  /// same moment still get distinct numbers — this is how every doc id this
  /// service mints (`booking_NN`, `customer_NN`, ...) stays sequential
  /// instead of a random Firestore auto-id.
  Future<String> _nextSequentialId({
    required String counterField,
    required String prefix,
    int pad = 2,
  }) async {
    final counterRef = _db.collection('meta').doc('counters');
    return _db.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final current = (snapshot.data()?[counterField] as num?)?.toInt() ?? 0;
      final next = current + 1;
      transaction.set(
        counterRef,
        {counterField: next},
        SetOptions(merge: true),
      );
      return '$prefix${next.toString().padLeft(pad, '0')}';
    });
  }

  /// Looks up a `customers` document by phone number, creating one with a
  /// sequential `customer_NN` id if it doesn't exist yet, and returns its
  /// document id.
  Future<String> _findOrCreateCustomer(ClientInfo client) async {
    final phone = client.phone.trim();
    final existing = await _db
        .collection('customers')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final counterRef = _db.collection('meta').doc('counters');
    return _db.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final next =
          ((snapshot.data()?['customerSeq'] as num?)?.toInt() ?? 0) + 1;
      final id = 'customer_${next.toString().padLeft(2, '0')}';
      final clientId =
          'LUX-${DateTime.now().year}-${next.toString().padLeft(3, '0')}';

      transaction.set(
        counterRef,
        {'customerSeq': next},
        SetOptions(merge: true),
      );
      transaction.set(_db.collection('customers').doc(id), {
        'clientId': clientId,
        'fullName': client.fullName.trim(),
        'email': client.email.trim(),
        'phone': phone,
        'facebook': client.facebook.trim(),
        'memberSince': FieldValue.serverTimestamp(),
        'totalVisits': 0,
        'totalSpent': 0,
        'noShowCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return id;
    });
  }
}
