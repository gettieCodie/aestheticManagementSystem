import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../auth/state/auth_controller.dart';
import '../models/invoice.dart';
import '../state/billing_store.dart';
import '../../../core/widgets/app_toast.dart';

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
  final _reference = TextEditingController();
  final _received = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  bool _submitting = false;
  String? _error;

  double get _amountValue => double.tryParse(_amount.text) ?? 0;
  double get _receivedValue => double.tryParse(_received.text) ?? 0;
  double get _change =>
      (_receivedValue - _amountValue).clamp(0, double.infinity).toDouble();

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
    _reference.dispose();
    _received.dispose();
    super.dispose();
  }

  Future<void> _confirm(Invoice invoice) async {
    final amount = _amountValue;
    if (amount <= 0 || _submitting) return;

    // Method-specific validation.
    if (_method.requiresReference && _reference.text.trim().isEmpty) {
      setState(() => _error = 'Enter the ${_method.label} reference number.');
      return;
    }
    if (_method.isCash && _receivedValue < amount) {
      setState(() => _error = 'Amount received is less than the amount due.');
      return;
    }
    setState(() => _error = null);

    final staff = context.read<AuthController>().currentUser?.fullName ?? 'Staff';
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      await context.read<BillingStore>().recordPayment(
            invoiceId: invoice.id,
            amount: amount,
            method: _method,
            staffName: staff,
            note: _note.text.trim().isEmpty ? 'Payment' : _note.text.trim(),
            reference: _reference.text.trim(),
            amountReceived: _method.isCash ? _receivedValue : null,
            changeGiven: _method.isCash ? _change : null,
          );
      navigator.pop();
    } catch (e) {
      setState(() => _submitting = false);
      AppToast.errorOn(messenger, 'Could not record payment: $e');
    }
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
              onChanged: (_) => setState(() {}),
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
                      DropdownMenuItem(
                        value: m,
                        child: Row(children: [
                          Icon(m.icon, size: 18, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text(m.label),
                        ]),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _method = v ?? _method;
                    _error = null;
                  }),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Only the fields the chosen method needs.
            if (_method.isCash) ...[
              TextField(
                controller: _received,
                decoration: const InputDecoration(labelText: 'Amount received (₱)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Change'),
                    Text(Formatters.peso(_change),
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: scheme.primary)),
                  ],
                ),
              ),
            ] else
              TextField(
                controller: _reference,
                decoration: InputDecoration(
                  labelText: '${_method.label} reference number',
                  hintText: 'e.g. 0123456789',
                ),
                onChanged: (_) => setState(() {}),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: scheme.error, fontSize: 12)),
            ],
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
        TextButton(
            onPressed: _submitting ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _submitting ? null : () => _confirm(invoice),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Record'),
        ),
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
                              Row(children: [
                                Icon(p.method.icon,
                                    size: 14, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 5),
                                Text('${p.id} · ${p.method.label}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ]),
                              Text('${Formatters.date(p.date)} · ${p.note}',
                                  style: TextStyle(
                                      fontSize: 11, color: scheme.onSurfaceVariant)),
                              if (p.reference.isNotEmpty)
                                Text('Ref: ${p.reference}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSurfaceVariant)),
                              if (p.changeGiven != null && p.changeGiven! > 0)
                                Text(
                                    'Received ${Formatters.peso(p.amountReceived ?? 0)} · '
                                    'Change ${Formatters.peso(p.changeGiven!)}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSurfaceVariant)),
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
