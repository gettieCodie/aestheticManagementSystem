import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Why stock moved. Drives the icon and colour in the movement history.
enum MovementType {
  stockIn('Stock in', Icons.arrow_downward_rounded, AppColors.success),
  stockOut('Stock out', Icons.arrow_upward_rounded, AppColors.error),
  adjustment('Adjustment', Icons.import_export_rounded, AppColors.warning);

  const MovementType(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;

  static MovementType fromId(String? id) => switch (id) {
        'stockIn' => MovementType.stockIn,
        'stockOut' => MovementType.stockOut,
        _ => MovementType.adjustment,
      };

  String get id => name;
}

/// Preset reasons, so history stays queryable instead of free-text only.
const List<String> kStockInReasons = [
  'Supplier delivery',
  'Branch transfer in',
  'Customer return',
  'Stock count correction',
];

const List<String> kStockOutReasons = [
  'POS sale',
  'Used in treatment',
  'Branch transfer out',
  'Damaged / expired write-off',
  'Stock count correction',
];

/// One immutable entry in the stock ledger.
///
/// `stock` holds only the *current* quantity per branch; this collection is
/// the audit trail of how it got there. [delta] is signed — positive for
/// stock in, negative for stock out — and [resultingStock] snapshots the
/// branch quantity after the move so history reads correctly even if the
/// product is later edited or deleted.
class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.branch,
    required this.type,
    required this.delta,
    required this.date,
    required this.staffName,
    this.reason = '',
    this.remarks = '',
    this.resultingStock,
  });

  final String id;
  final String productId;
  final String productName;
  final String branch;
  final MovementType type;

  /// Signed change in units (+30, −2).
  final int delta;

  final DateTime date;
  final String staffName;
  final String reason;
  final String remarks;
  final int? resultingStock;

  String get signedLabel => delta > 0 ? '+$delta' : '$delta';
}
