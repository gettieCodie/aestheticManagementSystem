import 'package:flutter/material.dart';

/// A single bookable treatment/service.
///
/// [id] is the Firestore document id in the `services` collection (e.g.
/// `svc_01`).
@immutable
class ServiceModel {
  const ServiceModel({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.durationMinutes,
    required this.price,
    required this.icon,
  });

  /// Builds a [ServiceModel] from a `services/{id}` Firestore document.
  factory ServiceModel.fromMap(
    String id,
    Map<String, dynamic> data, {
    required IconData icon,
  }) {
    return ServiceModel(
      id: id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      description: data['description'] as String? ?? '',
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 0,
      price: (data['price'] as num?)?.toDouble() ?? 0,
      icon: icon,
    );
  }

  final String id;
  final String name;
  final String category;
  final String description;
  final int durationMinutes;
  final double price;
  final IconData icon;

  @override
  bool operator ==(Object other) => other is ServiceModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
