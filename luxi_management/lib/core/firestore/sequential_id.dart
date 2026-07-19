import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared atomic id-sequence allocator backed by `meta/counters` — the same
/// document/collection `luxi_appointment`'s `BookingDataService` uses for
/// `bookingSeq`/`customerSeq`, so ids stay unique and sequential no matter
/// which app (or which repository in this app) creates the record.
class SequentialIdAllocator {
  SequentialIdAllocator(this._db);

  final FirebaseFirestore _db;

  /// Returns the next `{prefix}NN` id for [collection], atomically bumping
  /// `meta/counters.$counterField`.
  ///
  /// Self-healing: if the counter is stale or missing relative to what's
  /// actually in [collection] — e.g. seed data was written straight into
  /// Firestore without going through this allocator, so the counter never
  /// advanced — the naive `counter + 1` id would already be taken, and a
  /// plain `.set()` on it would silently overwrite that existing doc instead
  /// of creating a new one. To avoid that, this checks the candidate id
  /// against [collection] and keeps advancing until it finds one that's
  /// actually free, persisting the corrected counter so subsequent calls
  /// don't repeat the check.
  Future<String> next({
    required String counterField,
    required String prefix,
    required String collection,
    int pad = 2,
  }) async {
    final counterRef = _db.collection('meta').doc('counters');
    final targetCollection = _db.collection(collection);
    return _db.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      var candidate = (snapshot.data()?[counterField] as num?)?.toInt() ?? 0;
      String id;
      while (true) {
        candidate += 1;
        id = '$prefix${candidate.toString().padLeft(pad, '0')}';
        final existing = await transaction.get(targetCollection.doc(id));
        if (!existing.exists) break;
      }
      transaction.set(
        counterRef,
        {counterField: candidate},
        SetOptions(merge: true),
      );
      return id;
    });
  }
}
