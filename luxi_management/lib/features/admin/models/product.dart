import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// The four clinic branches, used across inventory and sales.
const List<String> kBranches = ['Laguna', 'Batangas', 'Lipa', 'Pampanga'];

enum InventoryStatus {
  inStock('In Stock', AppColors.success),
  lowStock('Low Stock', AppColors.warning),
  critical('Critical', AppColors.error),
  outOfStock('Out of Stock', AppColors.error);

  const InventoryStatus(this.label, this.color);
  final String label;
  final Color color;
}

/// An inventory product with per-branch stock (Inventory Management).
class Product {
  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.supplier,
    required this.unit,
    required this.price,
    required this.cost,
    required this.reorderLevel,
    required this.criticalLevel,
    required this.branchStock,
    this.brand = '',
    this.expiryDate,
    this.createdAt,
  });

  final String id;
  final String name;
  final String sku;
  final String category;
  final String supplier;
  final String unit;
  final double price;
  final double cost;
  final int reorderLevel;
  final int criticalLevel;

  /// Optional catalog details. Both default to empty/null so products created
  /// before these fields existed keep loading unchanged.
  final String brand;
  final DateTime? expiryDate;

  /// When the product was first created (used for "Sort by Date Added").
  final DateTime? createdAt;

  /// Within [days] of expiring (and not already expired long ago).
  bool expiringWithin(int days) {
    final d = expiryDate;
    if (d == null) return false;
    final diff = d.difference(DateTime.now()).inDays;
    return diff <= days;
  }

  bool get isExpiringSoon => expiringWithin(60);

  /// branch name → quantity on hand.
  final Map<String, int> branchStock;

  int get totalStock =>
      branchStock.values.fold(0, (sum, qty) => sum + qty);

  double get inventoryValue => totalStock * cost;

  InventoryStatus get status {
    final total = totalStock;
    if (total <= 0) return InventoryStatus.outOfStock;
    if (total <= criticalLevel) return InventoryStatus.critical;
    if (total <= reorderLevel) return InventoryStatus.lowStock;
    return InventoryStatus.inStock;
  }

  Product copyWith({
    String? name,
    String? sku,
    String? category,
    String? supplier,
    String? unit,
    double? price,
    double? cost,
    int? reorderLevel,
    int? criticalLevel,
    Map<String, int>? branchStock,
    String? brand,
    DateTime? expiryDate,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      supplier: supplier ?? this.supplier,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      criticalLevel: criticalLevel ?? this.criticalLevel,
      branchStock: branchStock ?? this.branchStock,
      brand: brand ?? this.brand,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }
}
