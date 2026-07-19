import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/branch_lookup.dart';
import '../../../core/firestore/firestore_dates.dart';
import '../../../core/firestore/sequential_id.dart';
import '../models/customer.dart';

/// One row from the `packages` collection, paired with the `customerId` it
/// belongs to (packages are top-level in Firestore, not nested under the
/// customer) — [StaffStore] groups these by customer.
typedef PackageRow = ({String customerId, TreatmentPackage package});

/// Firestore-backed source of truth for `customers` (-> [Customer], base
/// fields only) and `packages` (-> [TreatmentPackage], grouped by
/// `customerId` by the caller). Session history is intentionally NOT stored
/// here — [StaffStore] derives it from completed `bookings`, since a
/// completed booking already carries the treatment-record fields
/// (productsUsed/notes/photoCount), and the schema has no separate sessions
/// collection.
///
/// `customer_NN` ids come from the same `meta/counters.customerSeq` counter
/// `luxi_appointment`'s `BookingDataService` uses, so a walk-in added here
/// and a client who books online never collide.
class CustomersRepository {
  CustomersRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance,
        _ids = SequentialIdAllocator(firestore ?? FirebaseFirestore.instance);

  final FirebaseFirestore _db;
  final SequentialIdAllocator _ids;

  Stream<List<Customer>> watchCustomers() {
    return _db.collection('customers').snapshots().map(
          (snap) =>
              snap.docs.map((doc) => _customerFromDoc(doc.id, doc.data())).toList(),
        );
  }

  Customer _customerFromDoc(String id, Map<String, dynamic> data) {
    return Customer(
      id: id,
      clientId: data['clientId'] as String? ?? id,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      facebook: data['facebook'] as String? ?? '',
      memberSince:
          (data['memberSince'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: data['notes'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Stream<List<PackageRow>> watchPackages() {
    return _db.collection('packages').snapshots().map(
          (snap) => snap.docs
              .map((doc) => (
                    customerId: doc.data()['customerId'] as String? ?? '',
                    package: _packageFromDoc(doc.id, doc.data()),
                  ))
              .toList(),
        );
  }

  TreatmentPackage _packageFromDoc(String id, Map<String, dynamic> data) {
    return TreatmentPackage(
      id: id,
      name: data['name'] as String? ?? '',
      totalSessions: (data['totalSessions'] as num?)?.toInt() ?? 0,
      completedSessions: (data['completedSessions'] as num?)?.toInt() ?? 0,
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0,
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0,
      sessionIntervalDays: (data['sessionIntervalDays'] as num?)?.toInt() ?? 7,
      invoiceId: data['invoiceId'] as String?,
    );
  }

  /// Creates a `customer_NN` record. Mirrors
  /// `BookingDataService._findOrCreateCustomer` in `luxi_appointment` field
  /// for field, sharing the same counter, so both apps' numbering agrees.
  Future<Customer> addCustomer({
    required String fullName,
    required String phone,
    String email = '',
    String facebook = '',
    String notes = '',
  }) async {
    final counterRef = _db.collection('meta').doc('counters');
    final memberSince = DateTime.now();
    return _db.runTransaction<Customer>((tx) async {
      final snapshot = await tx.get(counterRef);
      final next = ((snapshot.data()?['customerSeq'] as num?)?.toInt() ?? 0) + 1;
      final id = 'customer_${next.toString().padLeft(2, '0')}';
      final clientId = 'LUX-${memberSince.year}-${next.toString().padLeft(3, '0')}';

      tx.set(counterRef, {'customerSeq': next}, SetOptions(merge: true));
      tx.set(_db.collection('customers').doc(id), {
        'clientId': clientId,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'facebook': facebook,
        'notes': notes,
        'memberSince': Timestamp.fromDate(memberSince),
        'totalVisits': 0,
        'totalSpent': 0,
        'noShowCount': 0,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return Customer(
        id: id,
        clientId: clientId,
        fullName: fullName,
        email: email,
        phone: phone,
        facebook: facebook,
        notes: notes,
        memberSince: memberSince,
      );
    });
  }

  Future<void> updateCustomer(
    String id, {
    String? fullName,
    String? email,
    String? phone,
    String? facebook,
    String? notes,
  }) {
    final updates = <String, dynamic>{
      if (fullName != null) 'fullName': fullName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (facebook != null) 'facebook': facebook,
      if (notes != null) 'notes': notes,
    };
    if (updates.isEmpty) return Future.value();
    updates['updatedAt'] = FieldValue.serverTimestamp();
    return _db.collection('customers').doc(id).update(updates);
  }

  /// Creates a `package_NN` record for a customer (from POS).
  Future<TreatmentPackage> createPackage({
    required String customerId,
    required String name,
    required int totalSessions,
    required double totalPrice,
    required double paidAmount,
    int sessionIntervalDays = 7,
    String? invoiceId,
    String? branchShortName,
  }) async {
    final id = await _ids.next(
        counterField: 'packageSeq', prefix: 'package_', collection: 'packages');
    final branchId =
        branchShortName == null ? null : BranchLookup.idByShortName[branchShortName];

    await _db.collection('packages').doc(id).set({
      'customerId': customerId,
      'name': name,
      'totalSessions': totalSessions,
      'completedSessions': 0,
      'totalPrice': totalPrice,
      'paidAmount': paidAmount,
      'remainingBalance': totalPrice - paidAmount,
      'paymentStatus': paidAmount >= totalPrice ? 'fullyPaid' : 'installment',
      'sessionIntervalDays': sessionIntervalDays,
      'invoiceId': invoiceId,
      'branchId': branchId,
      'status': 'active',
      'startDate': FirestoreDates.dateOnly(DateTime.now()),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return TreatmentPackage(
      id: id,
      name: name,
      totalSessions: totalSessions,
      completedSessions: 0,
      totalPrice: totalPrice,
      paidAmount: paidAmount,
      sessionIntervalDays: sessionIntervalDays,
      invoiceId: invoiceId,
    );
  }

  Future<void> incrementPackageCompletedSessions(String packageId) {
    return _db.collection('packages').doc(packageId).update({
      'completedSessions': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
