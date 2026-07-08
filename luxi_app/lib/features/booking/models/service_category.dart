import 'package:flutter/material.dart';

import 'service_model.dart';

/// A named group of related [ServiceModel]s (e.g. "Facials & Skincare").
@immutable
class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.services,
  });

  final String id;
  final String title;
  final IconData icon;
  final List<ServiceModel> services;
}
