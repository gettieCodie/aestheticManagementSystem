/// A fixed-price promo package (admin-configured, chosen at POS).
class PromoPackage {
  const PromoPackage({
    required this.id,
    required this.name,
    required this.sessionCount,
    required this.fixedPrice,
  });

  final String id;
  final String name;
  final int sessionCount;
  final double fixedPrice;
}
