import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/sequential_id.dart';
import '../models/promo_package.dart';

/// Firestore-backed source of truth for the `promoPackages` collection —
/// shared with `luxi_appointment`'s package catalog.
class PromoPackagesRepository {
  PromoPackagesRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance,
        _ids = SequentialIdAllocator(firestore ?? FirebaseFirestore.instance);

  final FirebaseFirestore _db;
  final SequentialIdAllocator _ids;

  Stream<List<PromoPackage>> watchPromoPackages() {
    return _db.collection('promoPackages').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => _fromDoc(doc.id, doc.data()))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name)),
        );
  }

  PromoPackage _fromDoc(String id, Map<String, dynamic> data) {
    return PromoPackage(
      id: id,
      name: data['name'] as String? ?? '',
      sessionCount: (data['sessionCount'] as num?)?.toInt() ?? 0,
      fixedPrice: (data['fixedPrice'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<void> addPromoPackage(PromoPackage promo, {String category = 'General'}) async {
    final id = await _ids.next(
        counterField: 'promoSeq', prefix: 'promo_', collection: 'promoPackages');
    await _db.collection('promoPackages').doc(id).set({
      'name': promo.name,
      'sessionCount': promo.sessionCount,
      'fixedPrice': promo.fixedPrice,
      'category': category,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePromoPackage(PromoPackage promo) {
    return _db.collection('promoPackages').doc(promo.id).set({
      'name': promo.name,
      'sessionCount': promo.sessionCount,
      'fixedPrice': promo.fixedPrice,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deletePromoPackage(String id) =>
      _db.collection('promoPackages').doc(id).delete();
}
