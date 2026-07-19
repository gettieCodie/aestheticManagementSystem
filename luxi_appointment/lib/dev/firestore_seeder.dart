import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;

/// One-time helper that loads `assets/seed/luxi_firestore_dummy_data_60.json`
/// and writes it into Firestore, collection by collection, using each
/// record's `_id` as the document id.
///
/// Triggered from the "Seed demo data" button on the landing page (debug
/// builds only — see `landing_page.dart`). Safe to run more than once: every
/// write is a `set()` keyed by `_id`, so re-seeding just overwrites the same
/// docs instead of duplicating them.
class FirestoreSeeder {
  FirestoreSeeder({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static final RegExp _isoDateTime =
      RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$');

  /// Collections whose ids follow a `{prefix}NN` sequence, mapped to the
  /// counter field on `meta/counters` that tracks each one. Keep in sync with
  /// the prefixes [BookingDataService] mints via `_nextSequentialId`, and
  /// with `SequentialIdAllocator` usages such as
  /// `BillingRepository.createInvoice`/`recordPayment`.
  static final Map<String, ({String counterField, RegExp pattern})>
      _sequencedCollections = {
    'bookings': (counterField: 'bookingSeq', pattern: RegExp(r'^booking_(\d+)$')),
    'customers': (counterField: 'customerSeq', pattern: RegExp(r'^customer_(\d+)$')),
    'sales': (counterField: 'saleSeq', pattern: RegExp(r'^sale_(\d+)$')),
    'payments': (counterField: 'paymentSeq', pattern: RegExp(r'^payment_(\d+)$')),
  };

  /// Seeds every collection in the bundled JSON, then resets each sequence
  /// counter in `meta/counters` to the highest number found among the seeded
  /// docs for that collection — so the next doc the app creates continues
  /// from there (e.g. `booking_07` after seeding through `booking_06`). See
  /// [BookingDataService.createBooking].
  ///
  /// Returns the number of documents written per collection.
  Future<Map<String, int>> seed() async {
    final raw = await rootBundle.loadString(
      'assets/seed/luxi_firestore_dummy_data_60.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final summary = <String, int>{};
    final maxSeq = <String, int>{
      for (final entry in _sequencedCollections.values) entry.counterField: 0,
    };
    for (final entry in json.entries) {
      if (entry.key == '_meta') continue;
      final records = entry.value as List<dynamic>;
      final batch = _db.batch();
      final sequenced = _sequencedCollections[entry.key];
      for (final record in records) {
        final data =
            Map<String, dynamic>.from(record as Map<String, dynamic>);
        final id = data.remove('_id') as String;
        final transformed = _transform(data) as Map<String, dynamic>;
        batch.set(_db.collection(entry.key).doc(id), transformed);

        if (sequenced != null) {
          final match = sequenced.pattern.firstMatch(id);
          final seq = match == null ? null : int.tryParse(match.group(1)!);
          if (seq != null && seq > maxSeq[sequenced.counterField]!) {
            maxSeq[sequenced.counterField] = seq;
          }
        }
      }
      await batch.commit();
      summary[entry.key] = records.length;
    }

    await _db
        .collection('meta')
        .doc('counters')
        .set(maxSeq, SetOptions(merge: true));

    return summary;
  }

  /// Recursively converts full ISO-8601 datetime strings (e.g.
  /// `2026-01-05T08:00:00Z`) into Firestore [Timestamp]s. Date-only strings
  /// (e.g. `2026-04-26`) are left as plain strings, matching how the app
  /// itself stores `appointmentDate` in [BookingDataService.createBooking].
  dynamic _transform(dynamic value) {
    if (value is Map) {
      // `value is Map` only promotes to the raw `Map<dynamic, dynamic>` (not
      // `Map<String, dynamic>`), so an inferred `.map()` call here silently
      // produces a `Map<dynamic, dynamic>` — which then fails the
      // `as Map<String, dynamic>` cast in `seed()`. Pinning the output type
      // arguments explicitly avoids that.
      return value.map<String, dynamic>(
        (key, v) => MapEntry(key as String, _transform(v)),
      );
    }
    if (value is List) {
      return value.map(_transform).toList();
    }
    if (value is String && _isoDateTime.hasMatch(value)) {
      return Timestamp.fromDate(DateTime.parse(value));
    }
    return value;
  }
}
