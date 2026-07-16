import 'package:flutter/foundation.dart';

import '../models/invoice.dart';

/// Owns invoices and payments — the financial source of truth.
///
/// Firebase seam: `invoices` maps to the `sales` collection and `payments` to
/// the `payments` collection. Balance/status are derived, so there is never any
/// drift between what is owed and what has been paid.
class BillingStore extends ChangeNotifier {
  final List<Invoice> _invoices = [];
  final List<InvoicePayment> _payments = [];
  int _invSeq = 0;
  int _paySeq = 0;

  BillingStore() {
    _seed();
  }

  List<Invoice> get invoices =>
      List.unmodifiable(_invoices.reversed); // newest first
  List<InvoicePayment> get payments => List.unmodifiable(_payments);

  List<Invoice> get openInvoices =>
      _invoices.reversed.where((i) => i.balance > 0 && !i.voided).toList();

  List<InvoicePayment> paymentsFor(String invoiceId) =>
      _payments.where((p) => p.invoiceId == invoiceId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  Invoice? invoiceById(String id) {
    for (final i in _invoices) {
      if (i.id == id) return i;
    }
    return null;
  }

  // Totals for dashboards / reports.
  double get totalRevenue =>
      _invoices.where((i) => !i.voided).fold(0, (s, i) => s + i.total);
  double get totalCollected =>
      _invoices.where((i) => !i.voided).fold(0, (s, i) => s + i.amountPaid);
  double get outstanding =>
      _invoices.where((i) => !i.voided).fold(0, (s, i) => s + i.balance);

  String _nextInvoiceId() => 'INV-${(++_invSeq).toString().padLeft(4, '0')}';
  String _nextPaymentId() => 'PAY-${(++_paySeq).toString().padLeft(4, '0')}';

  /// Creates an invoice (the bill). Does not record any payment.
  Invoice createInvoice({
    required String customerId,
    required String customerName,
    required String branch,
    required String staffName,
    required List<InvoiceLineItem> items,
    required PaymentPlan plan,
    double discount = 0,
    String? packageId,
    DateTime? dueDate,
  }) {
    final invoice = Invoice(
      id: _nextInvoiceId(),
      customerId: customerId,
      customerName: customerName,
      branch: branch,
      staffName: staffName,
      items: items,
      discount: discount,
      createdAt: DateTime.now(),
      plan: plan,
      packageId: packageId,
      dueDate: dueDate,
    );
    _invoices.add(invoice);
    notifyListeners();
    return invoice;
  }

  /// Records a payment against an invoice and updates its running total.
  InvoicePayment? recordPayment({
    required String invoiceId,
    required double amount,
    required PaymentMethod method,
    required String staffName,
    String note = '',
  }) {
    final invoice = invoiceById(invoiceId);
    if (invoice == null || amount <= 0) return null;
    final applied = amount.clamp(0, invoice.balance).toDouble();
    final payment = InvoicePayment(
      id: _nextPaymentId(),
      invoiceId: invoiceId,
      amount: applied,
      method: method,
      date: DateTime.now(),
      staffName: staffName,
      note: note,
    );
    _payments.add(payment);
    invoice.amountPaid += applied;
    notifyListeners();
    return payment;
  }

  void voidInvoice(String invoiceId) {
    invoiceById(invoiceId)?.voided = true;
    notifyListeners();
  }

  // --- Seed data ----------------------------------------------------------
  void _seed() {
    // name, customerId, package, total, paid, method, staff, branch, daysAgo, dueInDays
    final rows = [
      ['Maria Santos', 'c1', 'Glasskin Facial Package', 17500.0, 8750.0, PaymentMethod.gcash, 'Angela Cruz', 'Laguna', 3, 14],
      ['Carlos Ramos', 'c2', 'Diamond Peel Package', 15000.0, 15000.0, PaymentMethod.cash, 'Isabel Fernandez', 'Batangas', 3, null],
      ['Ana Reyes', 'c3', 'Get Slim Package', 5999.0, 3000.0, PaymentMethod.card, 'Sofia Torres', 'Lipa', 2, 21],
      ['Roberto Cruz', '', 'Laser Treatment Package', 24000.0, 12000.0, PaymentMethod.gcash, 'Isabel Fernandez', 'Batangas', 2, 30],
      ['Elena Martinez', '', 'Chemical Peel Package', 22000.0, 22000.0, PaymentMethod.cash, 'Angela Cruz', 'Laguna', 1, null],
      ['Juan Dela Cruz', '', 'UA Ultimate Package', 5999.0, 2999.0, PaymentMethod.gcash, 'Miguel Santos', 'Pampanga', 6, -3],
      ['Isabella Morales', '', 'Skin Rejuvenation Package', 18500.0, 9250.0, PaymentMethod.card, 'Sofia Torres', 'Lipa', 4, 10],
      ['Miguel Rodriguez', '', 'Glasskin Facial Package', 17500.0, 17500.0, PaymentMethod.cash, 'Elena Garcia', 'Pampanga', 5, null],
      ['Patricia Santos', '', 'Diamond Peel Package', 15000.0, 6000.0, PaymentMethod.gcash, 'Carmen Reyes', 'Lipa', 7, 7],
    ];

    for (final r in rows) {
      final total = r[3] as double;
      final paid = r[4] as double;
      final daysAgo = r[8] as int;
      final dueInDays = r[9] as int?;
      final created = DateTime.now().subtract(Duration(days: daysAgo));
      final plan = paid >= total ? PaymentPlan.full : PaymentPlan.installment;

      final invoice = Invoice(
        id: _nextInvoiceId(),
        customerId: r[1] as String,
        customerName: r[0] as String,
        branch: r[7] as String,
        staffName: r[6] as String,
        items: [
          InvoiceLineItem(
              name: r[2] as String, type: 'package', quantity: 1, unitPrice: total),
        ],
        discount: 0,
        createdAt: created,
        plan: plan,
        dueDate: dueInDays == null ? null : created.add(Duration(days: dueInDays)),
        amountPaid: paid,
      );
      _invoices.add(invoice);

      if (paid > 0) {
        _payments.add(InvoicePayment(
          id: _nextPaymentId(),
          invoiceId: invoice.id,
          amount: paid,
          method: r[5] as PaymentMethod,
          date: created,
          staffName: r[6] as String,
          note: 'Initial payment',
        ));
      }
    }
  }
}
