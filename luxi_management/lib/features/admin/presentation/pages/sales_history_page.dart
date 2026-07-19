import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../billing/models/invoice.dart';
import '../../../billing/presentation/record_payment_dialog.dart';
import '../../../billing/state/billing_store.dart';
import '../../models/product.dart' show kBranches;
import '../widgets/section_card.dart';
import '../widgets/stat_card.dart';
import 'page_scaffold.dart';

/// Admin Sales & Reports — the invoice ledger with balances and collection.
class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  String _branch = 'All Branches';
  String _status = 'All Status';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BillingStore>();

    final filtered = store.invoices.where((inv) {
      final branchOk = _branch == 'All Branches' || inv.branch == _branch;
      final statusOk = _status == 'All Status' ||
          (_status == 'Overdue' ? inv.isOverdue : inv.status.label == _status);
      return branchOk && statusOk;
    }).toList();

    return AdminPageScaffold(
      title: 'Sales & Reports',
      subtitle: 'Invoices, balances, and payment collection',
      children: [
        StatRow(cards: [
          StatCard(
            label: 'Total Revenue (billed)',
            value: Formatters.peso(store.totalRevenue),
            icon: Icons.attach_money_rounded,
          ),
          StatCard(
            label: 'Collected',
            value: Formatters.peso(store.totalCollected),
            icon: Icons.payments_rounded,
            accent: const Color(0xFF3E9E6E),
          ),
          StatCard(
            label: 'Outstanding',
            value: Formatters.peso(store.outstanding),
            icon: Icons.error_outline_rounded,
            accent: const Color(0xFFE05252),
          ),
          StatCard(
            label: 'Invoices',
            value: '${store.invoices.length}',
            icon: Icons.receipt_long_rounded,
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Filters',
          icon: Icons.filter_alt_rounded,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _dropdown('Branch', _branch, ['All Branches', ...kBranches],
                  (v) => setState(() => _branch = v)),
              _dropdown('Status', _status, [
                'All Status',
                ...InvoiceStatus.values
                    .where((s) => s != InvoiceStatus.voided)
                    .map((s) => s.label),
                'Overdue',
              ], (v) => setState(() => _status = v)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Invoices (${filtered.length})',
          icon: Icons.receipt_long_rounded,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              headingTextStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              columns: const [
                DataColumn(label: Text('Invoice')),
                DataColumn(label: Text('Client')),
                DataColumn(label: Text('Item')),
                DataColumn(label: Text('Total')),
                DataColumn(label: Text('Paid')),
                DataColumn(label: Text('Balance')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Branch')),
                DataColumn(label: Text('Actions')),
              ],
              rows: [for (final inv in filtered) _row(context, inv)],
            ),
          ),
        ),
      ],
    );
  }

  DataRow _row(BuildContext context, Invoice inv) {
    final scheme = Theme.of(context).colorScheme;
    final overdue = inv.isOverdue;
    return DataRow(cells: [
      DataCell(Text(inv.id, style: const TextStyle(fontWeight: FontWeight.w600))),
      DataCell(Text(inv.customerName)),
      DataCell(Text(inv.items.isNotEmpty ? inv.items.first.name : '—')),
      DataCell(Text(Formatters.peso(inv.total))),
      DataCell(Text(Formatters.peso(inv.amountPaid),
          style: const TextStyle(color: Color(0xFF3E9E6E)))),
      DataCell(Text(Formatters.peso(inv.balance),
          style: TextStyle(
              color: inv.balance > 0 ? const Color(0xFFE05252) : scheme.onSurfaceVariant))),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: (overdue ? const Color(0xFFE05252) : inv.status.color)
              .withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(overdue ? 'Overdue' : inv.status.label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: overdue ? const Color(0xFFE05252) : inv.status.color)),
      )),
      DataCell(Text(inv.branch)),
      DataCell(Row(children: [
        IconButton(
          tooltip: 'Payment history',
          icon: const Icon(Icons.history_rounded, size: 18),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => PaymentHistorySheet(invoiceId: inv.id),
          ),
        ),
        if (inv.balance > 0 && !inv.voided)
          TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => RecordPaymentDialog(invoiceId: inv.id),
            ),
            child: const Text('Record Payment'),
          ),
      ])),
    ]);
  }

  Widget _dropdown(String label, String value, List<String> items,
      ValueChanged<String> onChanged) {
    return SizedBox(
      width: 220,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, isDense: true),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            items: [
              for (final i in items) DropdownMenuItem(value: i, child: Text(i)),
            ],
            onChanged: (v) => onChanged(v ?? value),
          ),
        ),
      ),
    );
  }
}
