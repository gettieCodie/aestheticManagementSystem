import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/branch_lookup.dart';
import '../../../core/firestore/firestore_dates.dart';
import '../../../core/firestore/sequential_id.dart';
import '../models/invoice.dart';

/// Firestore-backed source of truth for `sales` (-> [Invoice]) and
/// `payments` (-> [InvoicePayment]) — the same collections the schema
/// defines for POS activity. Balance/status live on the `sales` doc and are
/// kept consistent with the payments log via a transaction on every
/// [recordPayment], so the two collections never drift.
class BillingRepository {
  BillingRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance,
        _ids = SequentialIdAllocator(firestore ?? FirebaseFirestore.instance);

  final FirebaseFirestore _db;
  final SequentialIdAllocator _ids;

  static const Map<PaymentPlan, String> _planOut = {
    PaymentPlan.full: 'full',
    PaymentPlan.installment: 'installment',
    PaymentPlan.perSession: 'perSession',
    PaymentPlan.billLater: 'billLater',
  };
  static final Map<String, PaymentPlan> _planIn = {
    for (final e in _planOut.entries) e.value: e.key,
  };

  static const Map<PaymentMethod, String> _methodOut = {
    PaymentMethod.cash: 'cash',
    PaymentMethod.gcash: 'gcash',
    PaymentMethod.card: 'card',
  };
  static final Map<String, PaymentMethod> _methodIn = {
    for (final e in _methodOut.entries) e.value: e.key,
  };

  Stream<List<Invoice>> watchInvoices() {
    return _db.collection('sales').snapshots().map(
          (snap) => snap.docs
              .map((doc) => _invoiceFromDoc(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<InvoicePayment>> watchPayments() {
    return _db.collection('payments').snapshots().map(
          (snap) => snap.docs
              .map((doc) => _paymentFromDoc(doc.id, doc.data()))
              .toList(),
        );
  }

  Invoice _invoiceFromDoc(String id, Map<String, dynamic> data) {
    final items = (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => InvoiceLineItem(
              name: m['name'] as String? ?? '',
              type: m['type'] as String? ?? 'service',
              quantity: (m['quantity'] as num?)?.toInt() ?? 1,
              unitPrice: (m['unitPrice'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
    final branchId = data['branchId'] as String?;
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return Invoice(
      id: id,
      customerId: data['customerId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      branch: BranchLookup.shortNameById[branchId] ??
          data['branchName'] as String? ??
          '',
      staffName: data['staffName'] as String? ?? '',
      items: items,
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
      createdAt: createdAt,
      plan: _planIn[data['plan'] as String?] ?? PaymentPlan.full,
      packageId: data['packageId'] as String?,
      dueDate: FirestoreDates.parseDateOnly(data['dueDate'] as String?),
      amountPaid: (data['paidAmount'] as num?)?.toDouble() ?? 0,
      voided: data['voided'] as bool? ?? false,
    );
  }

  InvoicePayment _paymentFromDoc(String id, Map<String, dynamic> data) {
    return InvoicePayment(
      id: id,
      invoiceId: data['invoiceId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      method: _methodIn[data['paymentMethod'] as String?] ?? PaymentMethod.cash,
      date: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      staffName: data['staffName'] as String? ?? '',
      note: data['note'] as String? ?? '',
    );
  }

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
  }) async {
    final id = await _ids.next(
        counterField: 'saleSeq', prefix: 'sale_', collection: 'sales');
    final branchId = BranchLookup.idByShortName[branch];
    final subtotal = items.fold<double>(0, (s, i) => s + i.lineTotal);
    final total = (subtotal - discount).clamp(0, double.infinity);
    final createdAt = DateTime.now();

    await _db.collection('sales').doc(id).set({
      'branchId': branchId,
      'branchName':
          branchId != null ? BranchLookup.fullNameById[branchId] : branch,
      'staffName': staffName,
      'customerId': customerId,
      'customerName': customerName,
      'packageId': packageId,
      'items': [
        for (final i in items)
          {
            'type': i.type,
            'name': i.name,
            'quantity': i.quantity,
            'unitPrice': i.unitPrice,
            'lineTotal': i.lineTotal,
          },
      ],
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'paidAmount': 0,
      'balance': total,
      'plan': _planOut[plan],
      'paymentStatus': 'unpaid',
      'dueDate': dueDate == null ? null : FirestoreDates.dateOnly(dueDate),
      'voided': false,
      'createdAt': Timestamp.fromDate(createdAt),
    });

    return Invoice(
      id: id,
      customerId: customerId,
      customerName: customerName,
      branch: branch,
      staffName: staffName,
      items: items,
      discount: discount,
      createdAt: createdAt,
      plan: plan,
      packageId: packageId,
      dueDate: dueDate,
    );
  }

  /// Records a payment against a sale, clamped to its remaining balance, and
  /// atomically updates the sale's `paidAmount`/`balance`/`paymentStatus` in
  /// the same transaction. Returns null if there's nothing to apply
  /// (amount <= 0, sale missing, or already fully paid).
  Future<InvoicePayment?> recordPayment({
    required String invoiceId,
    required double amount,
    required PaymentMethod method,
    required String staffName,
    String note = '',
  }) async {
    if (amount <= 0) return null;
    final id = await _ids.next(
        counterField: 'paymentSeq', prefix: 'payment_', collection: 'payments');
    final date = DateTime.now();
    final saleRef = _db.collection('sales').doc(invoiceId);
    final paymentRef = _db.collection('payments').doc(id);

    var applied = 0.0;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(saleRef);
      final data = snap.data();
      if (data == null) return;
      final total = (data['total'] as num?)?.toDouble() ?? 0;
      final paidSoFar = (data['paidAmount'] as num?)?.toDouble() ?? 0;
      final balance = (total - paidSoFar).clamp(0, double.infinity);
      applied = amount.clamp(0, balance).toDouble();
      if (applied <= 0) return;
      final newPaid = paidSoFar + applied;

      tx.set(paymentRef, {
        'invoiceId': invoiceId,
        'amount': applied,
        'paymentMethod': _methodOut[method],
        'staffName': staffName,
        'note': note,
        'createdAt': Timestamp.fromDate(date),
      });
      tx.update(saleRef, {
        'paidAmount': newPaid,
        'balance': (total - newPaid).clamp(0, double.infinity),
        'paymentStatus': newPaid >= total ? 'fullyPaid' : 'installment',
      });
    });

    if (applied <= 0) return null;
    return InvoicePayment(
      id: id,
      invoiceId: invoiceId,
      amount: applied,
      method: method,
      date: date,
      staffName: staffName,
      note: note,
    );
  }

  Future<void> voidInvoice(String invoiceId) {
    return _db.collection('sales').doc(invoiceId).update({'voided': true});
  }
}
