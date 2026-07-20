import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/firestore/store_errors.dart';
import '../models/invoice.dart';
import '../services/billing_repository.dart';

/// Owns invoices and payments — the financial source of truth. Backed live
/// by Firestore's `sales` (-> [Invoice]) and `payments` (-> [InvoicePayment])
/// collections via [BillingRepository]; every mutation writes straight
/// through, and the live streams reflect the change back here.
///
/// See [FirestoreErrorTracker.firestoreErrors] if totals look stuck at zero.
class BillingStore extends ChangeNotifier with FirestoreErrorTracker {
  BillingStore({BillingRepository? repository})
      : _repo = repository ?? BillingRepository() {
    _invoicesSub = _repo.watchInvoices().listen((list) {
      clearStreamError('invoices');
      _invoices = list;
      notifyListeners();
    }, onError: (Object e) => reportStreamError('invoices', e));
    _paymentsSub = _repo.watchPayments().listen((list) {
      clearStreamError('payments');
      _payments = list;
      notifyListeners();
    }, onError: (Object e) => reportStreamError('payments', e));
  }

  final BillingRepository _repo;
  late final StreamSubscription<List<Invoice>> _invoicesSub;
  late final StreamSubscription<List<InvoicePayment>> _paymentsSub;

  @override
  void dispose() {
    _invoicesSub.cancel();
    _paymentsSub.cancel();
    super.dispose();
  }

  List<Invoice> _invoices = [];
  List<InvoicePayment> _payments = [];

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

  /// Creates an invoice (the bill). Does not record any payment.
  Future<Invoice> createInvoice({
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
    return _repo.createInvoice(
      customerId: customerId,
      customerName: customerName,
      branch: branch,
      staffName: staffName,
      items: items,
      plan: plan,
      discount: discount,
      packageId: packageId,
      dueDate: dueDate,
    );
  }

  /// Records a payment against an invoice and updates its running total.
  Future<InvoicePayment?> recordPayment({
    required String invoiceId,
    required double amount,
    required PaymentMethod method,
    required String staffName,
    String note = '',
    String reference = '',
    double? amountReceived,
    double? changeGiven,
  }) {
    return _repo.recordPayment(
      invoiceId: invoiceId,
      amount: amount,
      method: method,
      staffName: staffName,
      note: note,
      reference: reference,
      amountReceived: amountReceived,
      changeGiven: changeGiven,
    );
  }

  Future<void> voidInvoice(String invoiceId) => _repo.voidInvoice(invoiceId);
}
