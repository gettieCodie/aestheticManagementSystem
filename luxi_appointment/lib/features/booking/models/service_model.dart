import 'package:flutter/material.dart';

/// A single bookable treatment/service.
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

  final int id;
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
