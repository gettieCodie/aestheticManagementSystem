import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../auth/state/auth_controller.dart';
import '../models/invoice.dart';
import '../state/billing_store.dart';

/// Records a payment against an existing invoice. Reused by Sales & Reports and
/// the POS Payments tab, so collection logic lives in exactly one place.
class RecordPaymentDialog extends StatefulWidget {
  const RecordPaymentDialog({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  State<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<RecordPaymentDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    final inv = context.read<BillingStore>().invoiceById(widget.invoiceId);
    if (inv != null) _amount.text = inv.balance.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _confirm(Invoice invoice) {
    final amount = double.tryParse(_amount.text) ?? 0;
    if (amount <= 0) return;
    final staff = context.read<AuthController>().currentUser?.fullName ?? 'Staff';
    context.read<BillingStore>().recordPayment(
          invoiceId: invoice.id,
          amount: amount,
          method: _method,
          staffName: staff,
          note: _note.text.trim().isEmpty ? 'Payment' : _note.text.trim(),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final invoice = context.watch<BillingStore>().invoiceById(widget.invoiceId);
    if (invoice == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Record Payment · ${invoice.id}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${invoice.customerName} — balance ${Formatters.peso(invoice.balance)}',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              decoration: const InputDecoration(labelText: 'Amount (₱)'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Method', isDense: true),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<PaymentMethod>(
                  value: _method,
                  isExpanded: true,
                  items: [
                    for (final m in PaymentMethod.values)
                      DropdownMenuItem(value: m, child: Text(m.label)),
                  ],
                  onChanged: (v) => setState(() => _method = v ?? _method),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. Session 3, installment',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => _confirm(invoice), child: const Text('Record')),
      ],
    );
  }
}

/// Shows an invoice's payment history (the ledger).
class PaymentHistorySheet extends StatelessWidget {
  const PaymentHistorySheet({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BillingStore>();
    final invoice = store.invoiceById(invoiceId);
    final payments = store.paymentsFor(invoiceId);
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Payment History · $invoiceId'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (invoice != null)
              Text(
                'Total ${Formatters.peso(invoice.total)} · '
                'Paid ${Formatters.peso(invoice.amountPaid)} · '
                'Balance ${Formatters.peso(invoice.balance)}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            const SizedBox(height: 12),
            if (payments.isEmpty)
              const Text('No payments yet.')
            else
              ...payments.map((p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${p.id} · ${p.method.label}',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('${Formatters.date(p.date)} · ${p.note}',
                                  style: TextStyle(
                                      fontSize: 11, color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Text(Formatters.peso(p.amount),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}
