import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum PaymentMethod {
  cash('Cash', Icons.payments_rounded),
  gcash('GCash', Icons.account_balance_wallet_rounded),
  maya('Maya', Icons.account_balance_wallet_rounded),
  creditCard('Credit Card', Icons.credit_card_rounded),
  debitCard('Debit Card', Icons.credit_card_rounded),
  bankTransfer('Bank Transfer', Icons.account_balance_rounded);

  const PaymentMethod(this.label, this.icon);
  final String label;
  final IconData icon;

  /// Cash captures amount received + change; every other method captures a
  /// reference / confirmation number instead.
  bool get isCash => this == PaymentMethod.cash;
  bool get requiresReference => !isCash;
}

/// How the client intends to settle the invoice (informational + UI hint).
/// Installment and Bill Later were retired — every sale is either paid in
/// full now or paid one package session at a time.
enum PaymentPlan {
  full('Full Payment'),
  perSession('Session Payment');

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
    this.appointmentDate,
    this.appointmentTime,
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

  /// The original appointment this sale settles, if it came from completing
  /// a treatment session (e.g. "10:30 AM") — null for a sale rung up directly
  /// at POS with no appointment behind it.
  final DateTime? appointmentDate;
  final String? appointmentTime;

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
    this.reference = '',
    this.amountReceived,
    this.changeGiven,
  });

  final String id;
  final String invoiceId;
  final double amount;
  final PaymentMethod method;
  final DateTime date;
  final String staffName;
  final String note;

  /// Confirmation / reference number for non-cash methods.
  final String reference;

  /// Cash only — tendered amount and the change handed back.
  final double? amountReceived;
  final double? changeGiven;
}
