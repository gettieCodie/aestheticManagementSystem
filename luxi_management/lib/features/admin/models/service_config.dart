/// A configurable service/treatment (POS Configuration → Services & Pricing).
class ServiceConfig {
  ServiceConfig({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.price,
    this.consumables = const [],
  });

  final String id;
  final String name;
  final int durationMinutes;
  final double price;

  /// Product names auto-used per session (drives inventory deduction later).
  final List<String> consumables;

  ServiceConfig copyWith({
    String? name,
    int? durationMinutes,
    double? price,
    List<String>? consumables,
  }) {
    return ServiceConfig(
      id: id,
      name: name ?? this.name,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      price: price ?? this.price,
      consumables: consumables ?? this.consumables,
    );
  }
}
