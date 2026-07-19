import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum PaymentMethod {
  cash('Cash'),
  gcash('GCash'),
  card('Card');

  const PaymentMethod(this.label);
  final String label;
}

/// How the client intends to settle the invoice (informational + UI hint).
enum PaymentPlan {
  full('Paid in full'),
  installment('Installment'),
  perSession('Per session'),
  billLater('Bill later');

  const PaymentPlan(this.label);
  final String label;
}

/// Derived from balance — never hand-set.
enum InvoiceStatus {
  paid('Paid', AppColors.success),
  partiallyPaid('Partially Paid', AppColors.primary),
  unpaid('Unpaid', AppColors.warning),
  voided('Void', AppColors.textSecondary);

  const InvoiceStatus(this.label, this.color);
  final String label;
  final Color color;
}

/// A single billed line (a package, a service, or a product).
class InvoiceLineItem {
  const InvoiceLineItem({
    required this.name,
    required this.type, // 'package' | 'service' | 'product'
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final String type;
  final int quantity;
  final double unitPrice;

  double get lineTotal => quantity * unitPrice;
}

/// The bill for one sale — the single source of truth for what is owed.
class Invoice {
  Invoice({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.branch,
    required this.staffName,
    required this.items,
    required this.discount,
    required this.createdAt,
    required this.plan,
    this.packageId,
    this.dueDate,
    this.amountPaid = 0,
    this.voided = false,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String branch;
  final String staffName;
  final List<InvoiceLineItem> items;
  final double discount;
  final DateTime createdAt;
  final PaymentPlan plan;
  final String? packageId;
  final DateTime? dueDate;

  /// Cached sum of payments (the payments list in the store is the audit log).
  double amountPaid;
  bool voided;

  double get subtotal => items.fold(0, (sum, i) => sum + i.lineTotal);
  double get total => (subtotal - discount).clamp(0, double.infinity);
  double get balance => (total - amountPaid).clamp(0, double.infinity);

  InvoiceStatus get status {
    if (voided) return InvoiceStatus.voided;
    if (amountPaid <= 0) return InvoiceStatus.unpaid;
    if (amountPaid < total) return InvoiceStatus.partiallyPaid;
    return InvoiceStatus.paid;
  }

  bool get isOverdue =>
      !voided &&
      balance > 0 &&
      dueDate != null &&
      dueDate!.isBefore(DateTime.now());
}

/// An immutable record of money received against an invoice.
class InvoicePayment {
  const InvoicePayment({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.method,
    required this.date,
    required this.staffName,
    this.note = '',
  });

  final String id;
  final String invoiceId;
  final double amount;
  final PaymentMethod method;
  final DateTime date;
  final String staffName;
  final String note;
}
