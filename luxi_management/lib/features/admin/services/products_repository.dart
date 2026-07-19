import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/branch_lookup.dart';
import '../../../core/firestore/sequential_id.dart';
import '../models/product.dart';

/// Firestore-backed source of truth for inventory.
///
/// The schema normalizes this into two collections — `products` (catalog
/// info) and `stock` (per-branch quantity, doc id `{branchId}_{productId}`)
/// — while the local [Product] model denormalizes stock onto the product as
/// a `branchStock` map. This repository merges the two collections live and
/// splits them back apart on write.
class ProductsRepository {
  ProductsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance,
        _ids = SequentialIdAllocator(firestore ?? FirebaseFirestore.instance);

  final FirebaseFirestore _db;
  final SequentialIdAllocator _ids;

  /// Live merge of `products` + `stock`. Either collection changing (from
  /// this app or `luxi_appointment`) re-emits the full merged list.
  Stream<List<Product>> watchProducts() {
    late final StreamController<List<Product>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? productsSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? stockSub;
    QuerySnapshot<Map<String, dynamic>>? lastProducts;
    QuerySnapshot<Map<String, dynamic>>? lastStock;

    void emit() {
      if (lastProducts == null || lastStock == null) return;
      controller.add(_merge(lastProducts!, lastStock!));
    }

    controller = StreamController<List<Product>>.broadcast(
      onListen: () {
        productsSub = _db.collection('products').snapshots().listen((snap) {
          lastProducts = snap;
          emit();
        });
        stockSub = _db.collection('stock').snapshots().listen((snap) {
          lastStock = snap;
          emit();
        });
      },
      onCancel: () {
        productsSub?.cancel();
        stockSub?.cancel();
      },
    );
    return controller.stream;
  }

  List<Product> _merge(
    QuerySnapshot<Map<String, dynamic>> products,
    QuerySnapshot<Map<String, dynamic>> stock,
  ) {
    final stockByProduct = <String, Map<String, int>>{};
    for (final doc in stock.docs) {
      final data = doc.data();
      final productId = data['productId'] as String?;
      final branchId = data['branchId'] as String?;
      final shortName =
          branchId == null ? null : BranchLookup.shortNameById[branchId];
      if (productId == null || shortName == null) continue;
      stockByProduct.putIfAbsent(productId, () => {})[shortName] =
          (data['quantity'] as num?)?.toInt() ?? 0;
    }

    return products.docs.map((doc) {
      final data = doc.data();
      return Product(
        id: doc.id,
        name: data['name'] as String? ?? '',
        sku: data['sku'] as String? ?? '',
        category: data['category'] as String? ?? '',
        supplier: data['supplier'] as String? ?? '',
        unit: data['unit'] as String? ?? 'pcs',
        price: (data['price'] as num?)?.toDouble() ?? 0,
        cost: (data['cost'] as num?)?.toDouble() ?? 0,
        reorderLevel: (data['reorderLevel'] as num?)?.toInt() ?? 0,
        criticalLevel: (data['criticalLevel'] as num?)?.toInt() ?? 0,
        branchStock: stockByProduct[doc.id] ??
            {for (final b in BranchLookup.idByShortName.keys) b: 0},
      );
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// [product.id] is ignored — a fresh `product_NN` id is minted here.
  Future<void> addProduct(Product product) async {
    final id = await _ids.next(
        counterField: 'productSeq', prefix: 'product_', collection: 'products');
    await _db.collection('products').doc(id).set({
      ..._toMap(product),
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _writeStock(id, product);
  }

  Future<void> updateProduct(Product product) async {
    await _db.collection('products').doc(product.id).set({
      ..._toMap(product),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _writeStock(product.id, product);
  }

  Future<void> deleteProduct(String id) async {
    await _db.collection('products').doc(id).delete();
    final stockDocs =
        await _db.collection('stock').where('productId', isEqualTo: id).get();
    final batch = _db.batch();
    for (final doc in stockDocs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Adjusts one branch's on-hand quantity for a product (e.g. after a sale
  /// or a manual stock count).
  Future<void> setStock({
    required String productId,
    required String productName,
    required String branchShortName,
    required int quantity,
  }) {
    final branchId = BranchLookup.idByShortName[branchShortName];
    if (branchId == null) return Future.value();
    return _db.collection('stock').doc('${branchId}_$productId').set({
      'branchId': branchId,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _writeStock(String productId, Product product) async {
    final batch = _db.batch();
    for (final entry in product.branchStock.entries) {
      final branchId = BranchLookup.idByShortName[entry.key];
      if (branchId == null) continue;
      batch.set(
        _db.collection('stock').doc('${branchId}_$productId'),
        {
          'branchId': branchId,
          'productId': productId,
          'productName': product.name,
          'quantity': entry.value,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Map<String, dynamic> _toMap(Product p) => {
        'name': p.name,
        'sku': p.sku,
        'category': p.category,
        'supplier': p.supplier,
        'unit': p.unit,
        'price': p.price,
        'cost': p.cost,
        'reorderLevel': p.reorderLevel,
        'criticalLevel': p.criticalLevel,
      };
}
