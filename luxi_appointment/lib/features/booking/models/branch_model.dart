import 'package:flutter/material.dart';

/// A clinic branch/location the client can book at.
///
/// [id] is the Firestore document id in the `branches` collection (e.g.
/// `branch_01`).
@immutable
class BranchModel {
  const BranchModel({
    required this.id,
    required this.name,
    required this.address,
    this.icon = Icons.location_city_rounded,
  });

  /// Builds a [BranchModel] from a `branches/{id}` Firestore document.
  factory BranchModel.fromMap(String id, Map<String, dynamic> data) {
    return BranchModel(
      id: id,
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final String address;
  final IconData icon;

  @override
  bool operator ==(Object other) => other is BranchModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
