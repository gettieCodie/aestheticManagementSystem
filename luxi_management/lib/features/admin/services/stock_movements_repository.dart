import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/branch_lookup.dart';
import '../models/stock_movement.dart';

/// Firestore-backed stock ledger (`stock_movements`).
///
/// Append-only: entries are never edited or deleted, so the history is a
/// reliable audit trail. Branches are stored by id (matching `stock` and
/// `sales`) and mapped back to short names for display.
class StockMovementsRepository {
  StockMovementsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Most recent [limit] movements, newest first.
  ///
  /// Capped because this collection grows without bound — every sale and
  /// delivery appends a row. Product-level views filter this list client-side.
  Stream<List<StockMovement>> watchMovements({int limit = 300}) {
    return _db
        .collection('stock_movements')
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  StockMovement _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final branchId = data['branchId'] as String?;
    return StockMovement(
      id: doc.id,
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? '',
      branch: (branchId == null ? null : BranchLookup.shortNameById[branchId]) ??
          (data['branch'] as String? ?? ''),
      type: MovementType.fromId(data['type'] as String?),
      delta: (data['delta'] as num?)?.toInt() ?? 0,
      // Freshly written docs read back with a null server timestamp once
      // before the server value lands; fall back to now so the row still sorts.
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      staffName: data['staffName'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      remarks: data['remarks'] as String? ?? '',
      resultingStock: (data['resultingStock'] as num?)?.toInt(),
    );
  }

  /// Appends one entry. Uses an auto id rather than the sequential allocator
  /// used elsewhere — movements are written far more often than catalog rows,
  /// and a shared counter would serialise every write behind one transaction.
  Future<void> add(StockMovement m) {
    return _db.collection('stock_movements').add({
      'productId': m.productId,
      'productName': m.productName,
      'branchId': BranchLookup.idByShortName[m.branch],
      'branch': m.branch,
      'type': m.type.id,
      'delta': m.delta,
      'date': FieldValue.serverTimestamp(),
      'staffName': m.staffName,
      'reason': m.reason,
      'remarks': m.remarks,
      if (m.resultingStock != null) 'resultingStock': m.resultingStock,
    });
  }
}
