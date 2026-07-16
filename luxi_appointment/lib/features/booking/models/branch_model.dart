import 'package:flutter/material.dart';

/// A clinic branch/location the client can book at.
@immutable
class BranchModel {
  const BranchModel({
    required this.id,
    required this.name,
    required this.address,
    this.icon = Icons.location_city_rounded,
  });

  final int id;
  final String name;
  final String address;
  final IconData icon;

  @override
  bool operator ==(Object other) => other is BranchModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
