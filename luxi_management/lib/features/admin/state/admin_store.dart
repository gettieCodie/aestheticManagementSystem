import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/firestore/store_errors.dart';
import '../models/product.dart';
import '../models/promo_package.dart';
import '../models/service_config.dart';
import '../services/products_repository.dart';
import '../services/promo_packages_repository.dart';
import '../services/services_repository.dart';
import '../services/settings_repository.dart';

/// Single store for all admin data — services, products/inventory, promo
/// packages, and settings — each backed live by Firestore via its own
/// repository. Every mutation writes straight through; the corresponding
/// stream listener reflects the change back into this store's getters and
/// calls [notifyListeners], so the UI never touches Firestore directly.
///
/// See [FirestoreErrorTracker.firestoreErrors] if [services]/[products]/etc.
/// are unexpectedly empty — a permission-denied or missing-index error fails
/// the underlying stream silently otherwise, which looks identical to "no
/// data yet" from the UI.
class AdminStore extends ChangeNotifier with FirestoreErrorTracker {
  AdminStore({
    ServicesRepository? servicesRepository,
    ProductsRepository? productsRepository,
    PromoPackagesRepository? promoPackagesRepository,
    SettingsRepository? settingsRepository,
  })  : _servicesRepo = servicesRepository ?? ServicesRepository(),
        _productsRepo = productsRepository ?? ProductsRepository(),
        _promoPackagesRepo =
            promoPackagesRepository ?? PromoPackagesRepository(),
        _settingsRepo = settingsRepository ?? SettingsRepository() {
    _servicesSub = _servicesRepo.watchServices().listen((list) {
      clearStreamError('services');
      _services = list;
      notifyListeners();
    }, onError: (Object e) => reportStreamError('services', e));
    _productsSub = _productsRepo.watchProducts().listen((list) {
      clearStreamError('products');
      _products = list;
      notifyListeners();
    }, onError: (Object e) => reportStreamError('products', e));
    _promoPackagesSub = _promoPackagesRepo.watchPromoPackages().listen((list) {
      clearStreamError('promoPackages');
      _promoPackages = list;
      notifyListeners();
    }, onError: (Object e) => reportStreamError('promoPackages', e));
    _settingsSub = _settingsRepo.watchSettings().listen((settings) {
      clearStreamError('settings');
      _promoDiscountRate = settings.promoDiscountRate;
      _paymentMethods = settings.paymentMethods;
      notifyListeners();
    }, onError: (Object e) => reportStreamError('settings', e));
  }

  final ServicesRepository _servicesRepo;
  final ProductsRepository _productsRepo;
  final PromoPackagesRepository _promoPackagesRepo;
  final SettingsRepository _settingsRepo;

  late final StreamSubscription<List<ServiceConfig>> _servicesSub;
  late final StreamSubscription<List<Product>> _productsSub;
  late final StreamSubscription<List<PromoPackage>> _promoPackagesSub;
  late final StreamSubscription<dynamic> _settingsSub;

  @override
  void dispose() {
    _servicesSub.cancel();
    _productsSub.cancel();
    _promoPackagesSub.cancel();
    _settingsSub.cancel();
    super.dispose();
  }

  // --- Services (POS Configuration) ----------------------------------------
  List<ServiceConfig> _services = [];
  List<ServiceConfig> get services => List.unmodifiable(_services);

  Future<void> addService(ServiceConfig service) =>
      _servicesRepo.addService(service);

  Future<void> updateService(ServiceConfig updated) =>
      _servicesRepo.updateService(updated);

  Future<void> deleteService(String id) => _servicesRepo.deleteService(id);

  /// Placeholder id for a brand-new [ServiceConfig] before it's saved — the
  /// repository mints the real `svc_NN` id on [addService].
  String newServiceId() => 's${DateTime.now().millisecondsSinceEpoch}';

  // --- Promo discount & payment methods -------------------------------------
  double _promoDiscountRate = 10;
  double get promoDiscountRate => _promoDiscountRate;
  Future<void> setPromoDiscountRate(double value) {
    _promoDiscountRate = value;
    notifyListeners();
    return _settingsRepo.setPromoDiscountRate(value);
  }

  Map<String, bool> _paymentMethods = const {
    'Cash': true,
    'GCash': true,
    'Credit/Debit Card': true,
  };
  Map<String, bool> get paymentMethods => Map.unmodifiable(_paymentMethods);

  Future<void> togglePaymentMethod(String method, bool enabled) {
    _paymentMethods = {..._paymentMethods, method: enabled};
    notifyListeners();
    return _settingsRepo.setPaymentMethods(_paymentMethods);
  }

  // --- Promo packages (catalog for POS) -------------------------------------
  List<PromoPackage> _promoPackages = [];
  List<PromoPackage> get promoPackages => List.unmodifiable(_promoPackages);

  Future<void> addPromoPackage(PromoPackage promo) =>
      _promoPackagesRepo.addPromoPackage(promo);

  Future<void> updatePromoPackage(PromoPackage promo) =>
      _promoPackagesRepo.updatePromoPackage(promo);

  Future<void> deletePromoPackage(String id) =>
      _promoPackagesRepo.deletePromoPackage(id);

  // --- Products (Inventory) -------------------------------------------------
  List<Product> _products = [];
  List<Product> get products => List.unmodifiable(_products);

  Future<void> addProduct(Product product) => _productsRepo.addProduct(product);

  Future<void> updateProduct(Product product) =>
      _productsRepo.updateProduct(product);

  Future<void> deleteProduct(String id) => _productsRepo.deleteProduct(id);

  Future<void> setStock({
    required String productId,
    required String productName,
    required String branch,
    required int quantity,
  }) =>
      _productsRepo.setStock(
        productId: productId,
        productName: productName,
        branchShortName: branch,
        quantity: quantity,
      );

  /// Placeholder id for a brand-new [Product] before it's saved — the
  /// repository mints the real `product_NN` id on [addProduct].
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
