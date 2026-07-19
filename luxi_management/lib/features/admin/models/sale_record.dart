import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum SalePaymentStatus {
  fullyPaid('Fully Paid', AppColors.success),
  installment('Installment', AppColors.primary),
  overdue('Overdue', AppColors.error);

  const SalePaymentStatus(this.label, this.color);
  final String label;
  final Color color;
}

/// A sales transaction (Sales History).
class SaleRecord {
  SaleRecord({
    required this.id,
    required this.client,
    required this.servicePackage,
    required this.total,
    required this.paid,
    required this.paymentMethod,
    required this.staff,
    required this.branch,
    required this.date,
    required this.status,
  });

  final String id;
  final String client;
  final String servicePackage;
  final double total;
  final double paid;
  final String paymentMethod;
  final String staff;
  final String branch;
  final DateTime date;
  final SalePaymentStatus status;

  double get balance => total - paid;
}
