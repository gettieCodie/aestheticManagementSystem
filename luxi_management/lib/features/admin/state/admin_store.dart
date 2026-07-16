import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/promo_package.dart';
import '../models/service_config.dart';

/// Single in-memory store for all admin data.
///
/// This is the seam for Firebase later: swap the seeded lists and the mutation
/// methods for Firestore reads/writes. The UI only talks to this store, so
/// nothing in the screens changes.
class AdminStore extends ChangeNotifier {
  // --- Services (POS Configuration) --------------------------------------
  final List<ServiceConfig> _services = [
    ServiceConfig(
        id: 's1',
        name: 'Facial Treatment',
        durationMinutes: 60,
        price: 1200,
        consumables: ['Cleansing Gel']),
    ServiceConfig(
        id: 's2',
        name: 'Acne Treatment Package',
        durationMinutes: 60,
        price: 9000,
        consumables: ['Acne Solution Set', 'Retinol Night Cream']),
    ServiceConfig(
        id: 's3',
        name: 'Whitening Facial',
        durationMinutes: 75,
        price: 1800,
        consumables: ['Vitamin C Serum', 'Brightening Toner']),
    ServiceConfig(
        id: 's4',
        name: 'Laser Hair Removal',
        durationMinutes: 45,
        price: 2500),
    ServiceConfig(
        id: 's5',
        name: 'Skin Rejuvenation Package',
        durationMinutes: 90,
        price: 15000,
        consumables: ['Vitamin C Serum', 'Retinol Night Cream']),
  ];

  List<ServiceConfig> get services => List.unmodifiable(_services);

  void addService(ServiceConfig service) {
    _services.add(service);
    notifyListeners();
  }

  void updateService(ServiceConfig updated) {
    final i = _services.indexWhere((s) => s.id == updated.id);
    if (i != -1) {
      _services[i] = updated;
      notifyListeners();
    }
  }

  void deleteService(String id) {
    _services.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  String newServiceId() => 's${DateTime.now().millisecondsSinceEpoch}';

  // --- Promo discount & payment methods ----------------------------------
  double _promoDiscountRate = 10;
  double get promoDiscountRate => _promoDiscountRate;
  void setPromoDiscountRate(double value) {
    _promoDiscountRate = value;
    notifyListeners();
  }

  final Map<String, bool> _paymentMethods = {
    'Cash': true,
    'GCash': true,
    'Credit/Debit Card': true,
  };
  Map<String, bool> get paymentMethods => Map.unmodifiable(_paymentMethods);
  void togglePaymentMethod(String method, bool enabled) {
    _paymentMethods[method] = enabled;
    notifyListeners();
  }

  // --- Promo packages (catalog for POS) ----------------------------------
  final List<PromoPackage> _promoPackages = const [
    PromoPackage(id: 'promo1', name: 'Get Slim Package', sessionCount: 40, fixedPrice: 5999),
    PromoPackage(id: 'promo2', name: 'UA Ultimate Package', sessionCount: 30, fixedPrice: 5999),
    PromoPackage(id: 'promo3', name: 'Skin Rejuvenation Promo', sessionCount: 20, fixedPrice: 8999),
  ];
  List<PromoPackage> get promoPackages => List.unmodifiable(_promoPackages);

  // --- Products (Inventory) ----------------------------------------------
  final List<Product> _products = [
    Product(
        id: 'p1', name: 'Sunscreen SPF50', sku: 'SKU-SUN-050', category: 'Skincare',
        supplier: 'BeautyCorp Inc.', unit: 'pcs', price: 599, cost: 300,
        reorderLevel: 30, criticalLevel: 15,
        branchStock: {'Laguna': 40, 'Batangas': 25, 'Lipa': 30, 'Pampanga': 25}),
    Product(
        id: 'p2', name: 'Whitening Cream', sku: 'SKU-WHT-100', category: 'Skincare',
        supplier: 'SkinCare Solutions', unit: 'bottles', price: 899, cost: 450,
        reorderLevel: 20, criticalLevel: 10,
        branchStock: {'Laguna': 20, 'Batangas': 15, 'Lipa': 25, 'Pampanga': 20}),
    Product(
        id: 'p3', name: 'Acne Solution Set', sku: 'SKU-ACN-200', category: 'Treatment',
        supplier: 'DermaTech Ltd.', unit: 'pcs', price: 1499, cost: 750,
        reorderLevel: 15, criticalLevel: 8,
        branchStock: {'Laguna': 15, 'Batangas': 12, 'Lipa': 10, 'Pampanga': 13}),
    Product(
        id: 'p4', name: 'Vitamin C Serum', sku: 'SKU-VTC-400', category: 'Serum',
        supplier: 'Premium Essentials', unit: 'bottles', price: 899, cost: 400,
        reorderLevel: 20, criticalLevel: 8,
        branchStock: {'Laguna': 5, 'Batangas': 4, 'Lipa': 3, 'Pampanga': 3}),
    Product(
        id: 'p5', name: 'Retinol Night Cream', sku: 'SKU-RET-500', category: 'Skincare',
        supplier: 'Premium Essentials', unit: 'bottles', price: 1299, cost: 650,
        reorderLevel: 15, criticalLevel: 6,
        branchStock: {'Laguna': 2, 'Batangas': 2, 'Lipa': 2, 'Pampanga': 2}),
    Product(
        id: 'p6', name: 'Cleansing Solution', sku: 'SKU-CLS-600', category: 'Professional Use',
        supplier: 'Professional Supplies Co.', unit: 'liters', price: 0, cost: 500,
        reorderLevel: 10, criticalLevel: 4,
        branchStock: {'Laguna': 2, 'Batangas': 1, 'Lipa': 1, 'Pampanga': 1}),
  ];

  List<Product> get products => List.unmodifiable(_products);

  void addProduct(Product product) {
    _products.add(product);
    notifyListeners();
  }

  String newProductId() => 'p${DateTime.now().millisecondsSinceEpoch}';

  double get totalInventoryValue =>
      _products.fold(0, (sum, p) => sum + p.inventoryValue);

  int get lowStockCount =>
      _products.where((p) => p.status == InventoryStatus.lowStock).length;
  int get criticalCount =>
      _products.where((p) => p.status == InventoryStatus.critical).length;
  int get outOfStockCount =>
      _products.where((p) => p.status == InventoryStatus.outOfStock).length;
}
