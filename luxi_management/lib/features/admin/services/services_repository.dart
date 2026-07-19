import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/sequential_id.dart';
import '../models/service_config.dart';

/// Firestore-backed source of truth for the `services` collection — shared
/// with `luxi_appointment`, which reads it to populate the client-facing
/// service picker. New services get a sequential `svc_NN` id.
class ServicesRepository {
  ServicesRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance,
        _ids = SequentialIdAllocator(firestore ?? FirebaseFirestore.instance);

  final FirebaseFirestore _db;
  final SequentialIdAllocator _ids;

  Stream<List<ServiceConfig>> watchServices() {
    return _db.collection('services').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => _fromDoc(doc.id, doc.data()))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name)),
        );
  }

  ServiceConfig _fromDoc(String id, Map<String, dynamic> data) {
    final consumables = (data['consumables'] as List?) ?? const [];
    return ServiceConfig(
      id: id,
      name: data['name'] as String? ?? '',
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 0,
      price: (data['price'] as num?)?.toDouble() ?? 0,
      consumables: consumables
          .whereType<Map>()
          .map((c) => c['productName'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList(),
    );
  }

  /// [service.id] is ignored — a fresh `svc_NN` id is minted here, since the
  /// caller only ever has a client-side placeholder id for a brand-new one.
  Future<void> addService(ServiceConfig service) async {
    final id = await _ids.next(
        counterField: 'serviceSeq', prefix: 'svc_', collection: 'services');
    await _db.collection('services').doc(id).set({
      ..._toMap(service),
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateService(ServiceConfig service) {
    return _db.collection('services').doc(service.id).set({
      ..._toMap(service),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteService(String id) =>
      _db.collection('services').doc(id).delete();

  Map<String, dynamic> _toMap(ServiceConfig s) => {
        'name': s.name,
        'durationMinutes': s.durationMinutes,
        'price': s.price,
        'consumables': [
          for (final name in s.consumables) {'productName': name, 'quantity': 1},
        ],
      };
}
