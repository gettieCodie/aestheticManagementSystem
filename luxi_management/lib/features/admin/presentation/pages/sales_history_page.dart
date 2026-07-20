import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
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
  static const int _pageSize = 10;

  String _branch = 'All Branches';
  String _status = 'All Status';
  int _page = 0;

  /// Narrowing the filters must return to page 1, or a shorter result set
  /// leaves the reader stranded on an empty page.
  void _resetPage() => _page = 0;

  List<String> get _statusOptions => [
        'All Status',
        ...InvoiceStatus.values
            .where((s) => s != InvoiceStatus.voided)
            .map((s) => s.label),
        'Overdue',
      ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BillingStore>();
    final isMobile = Responsive.isMobile(context);

    final filtered = store.invoices.where((inv) {
      final branchOk = _branch == 'All Branches' || inv.branch == _branch;
      final statusOk = _status == 'All Status' ||
          (_status == 'Overdue' ? inv.isOverdue : inv.status.label == _status);
      return branchOk && statusOk;
    }).toList();

    final pageCount = (filtered.length / _pageSize).ceil().clamp(1, 9999);
    final page = _page.clamp(0, pageCount - 1);
    final start = page * _pageSize;
    final visible = filtered.skip(start).take(_pageSize).toList();

    // KPIs reflect the current filters, not the whole ledger — voided
    // invoices are excluded the same way BillingStore's own totals are.
    final billable = filtered.where((i) => !i.voided);
    final filteredRevenue = billable.fold<double>(0, (s, i) => s + i.total);
    final filteredCollected = billable.fold<double>(0, (s, i) => s + i.amountPaid);
    final filteredOutstanding = billable.fold<double>(0, (s, i) => s + i.balance);

    return AdminPageScaffold(
      title: 'Sales & Reports',
      subtitle: 'Invoices, balances, and payment collection',
      children: [
        StatRow(cards: [
          StatCard(
            label: 'Total Revenue (billed)',
            value: Formatters.peso(filteredRevenue),
            icon: Icons.attach_money_rounded,
          ),
          StatCard(
            label: 'Collected',
            value: Formatters.peso(filteredCollected),
            icon: Icons.payments_rounded,
            accent: const Color(0xFF3E9E6E),
          ),
          StatCard(
            label: 'Outstanding',
            value: Formatters.peso(filteredOutstanding),
            icon: Icons.error_outline_rounded,
            accent: const Color(0xFFE05252),
          ),
          StatCard(
            label: 'Invoices',
            value: '${filtered.length}',
            icon: Icons.receipt_long_rounded,
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        // A whole card wrapping two tall dropdowns wasted most of a phone
        // screen; chips say the same thing in one row.
        if (isMobile)
          Row(
            children: [
              Expanded(
                child: _filterChip(
                  value: _branch,
                  allLabel: 'All Branches',
                  options: ['All Branches', ...kBranches],
                  onChanged: (v) => setState(() {
                    _branch = v;
                    _resetPage();
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _filterChip(
                  value: _status,
                  allLabel: 'All Status',
                  options: _statusOptions,
                  onChanged: (v) => setState(() {
                    _status = v;
                    _resetPage();
                  }),
                ),
              ),
            ],
          )
        else
          SectionCard(
            title: 'Filters',
            icon: Icons.filter_alt_rounded,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _dropdown('Branch', _branch, ['All Branches', ...kBranches],
                    (v) => setState(() {
                          _branch = v;
                          _resetPage();
                        })),
                _dropdown('Status', _status, _statusOptions,
                    (v) => setState(() {
                          _status = v;
                          _resetPage();
                        })),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Invoices (${filtered.length})',
          icon: Icons.receipt_long_rounded,
          child: isMobile
              // A nine-column table can't be read on a phone — one tappable
              // card per invoice, with the full breakdown a tap away.
              ? Column(
                  children: [
                    if (filtered.isEmpty)
                      const EmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'No invoices match these filters',
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Showing ${start + 1}–${start + visible.length} '
                            'of ${filtered.length}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                        ),
                      ),
                    for (final inv in visible) _InvoiceCard(invoice: inv),
                    if (pageCount > 1) _pager(context, page, pageCount),
                  ],
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 20,
                    showCheckboxColumn: false,
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
    return DataRow(
      // Rows are clickable too, so both layouts reach the same detail view.
      onSelectChanged: (_) => showInvoiceDetail(context, inv.id),
      cells: [
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

  /// Compact menu-backed chip used in place of a labelled dropdown on phones.
  Widget _filterChip({
    required String value,
    required String allLabel,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final active = value != allLabel;
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final o in options) PopupMenuItem(value: o, child: Text(o)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: active ? scheme.primary : scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? scheme.onPrimary : scheme.onSurface)),
            ),
            Icon(Icons.arrow_drop_down_rounded,
                size: 20,
                color: active ? scheme.onPrimary : scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  /// Prev / windowed page numbers / Next.
  Widget _pager(BuildContext context, int page, int pageCount) {
    final scheme = Theme.of(context).colorScheme;

    int windowStart = page - 2;
    if (windowStart > pageCount - 5) windowStart = pageCount - 5;
    if (windowStart < 0) windowStart = 0;
    final windowEnd = (windowStart + 5).clamp(0, pageCount);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: page == 0 ? null : () => setState(() => _page = page - 1),
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous page',
          ),
          for (int i = windowStart; i < windowEnd; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: SizedBox(
                width: 34,
                height: 34,
                child: Material(
                  color: i == page ? scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => setState(() => _page = i),
                    child: Center(
                      child: Text('${i + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                i == page ? FontWeight.w800 : FontWeight.w500,
                            color: i == page
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          )),
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            onPressed: page >= pageCount - 1
                ? null
                : () => setState(() => _page = page + 1),
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next page',
          ),
        ],
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items,
      ValueChanged<String> onChanged) {
    return SizedBox(
      // Full width on phones; fixed columns on desktop.
      width: Responsive.isMobile(context)
          ? MediaQuery.sizeOf(context).width - 96
          : 220,
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

/// Opens the formatted breakdown for an invoice.
void showInvoiceDetail(BuildContext context, String invoiceId) {
  showDialog<void>(
    context: context,
    builder: (_) => InvoiceDetailSheet(invoiceId: invoiceId),
  );
}

/// Compact, tappable invoice row for phones.
class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inv = invoice;
    final overdue = inv.isOverdue;
    final statusColor = overdue ? const Color(0xFFE05252) : inv.status.color;
    final statusLabel = overdue ? 'Overdue' : inv.status.label;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showInvoiceDetail(context, inv.id),
          // Two lines: who and how much, then when and what state. The item,
          // invoice number and payment breakdown are all in the detail sheet.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(inv.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                        Formatters.peso(
                            inv.balance > 0 ? inv.balance : inv.total),
                        style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: inv.balance > 0
                                ? const Color(0xFFE05252)
                                : scheme.onSurface)),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          '${Formatters.date(inv.createdAt)} · ${inv.branch}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                    ),
                    const SizedBox(width: 8),
                    Text(statusLabel,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: statusColor)),
                  ],
                ),
                if (inv.appointmentDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                        'Appointment ${Formatters.date(inv.appointmentDate!)} · '
                        '${inv.appointmentTime ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The full invoice: header, line items, totals, and the payment ledger.
///
/// Reads live from [BillingStore], so recording a payment from inside the
/// sheet updates it in place.
class InvoiceDetailSheet extends StatelessWidget {
  const InvoiceDetailSheet({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  Widget build(BuildContext context) {
    final billing = context.watch<BillingStore>();
    final inv = billing.invoiceById(invoiceId);
    final scheme = Theme.of(context).colorScheme;

    if (inv == null) {
      return const AlertDialog(content: Text('Invoice not found.'));
    }

    final payments = billing.paymentsFor(inv.id);
    final overdue = inv.isOverdue;
    final statusColor = overdue ? const Color(0xFFE05252) : inv.status.color;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.all(16),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(inv.id,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 17)),
                Text(Formatters.date(inv.createdAt),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(overdue ? 'Overdue' : inv.status.label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor)),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _meta(context, 'Client', inv.customerName),
              _meta(context, 'Branch', inv.branch),
              _meta(context, 'Handled by', inv.staffName),
              _meta(context, 'Payment plan', inv.plan.label),
              if (inv.dueDate != null)
                _meta(context, 'Due', Formatters.date(inv.dueDate!)),
              if (inv.appointmentDate != null)
                _meta(context, 'Appointment',
                    '${Formatters.date(inv.appointmentDate!)} · ${inv.appointmentTime ?? ''}'),
              const Divider(height: 26),
              _sectionLabel(context, 'Items'),
              for (final i in inv.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(
                                '${i.type} · ${i.quantity} × '
                                '${Formatters.peso(i.unitPrice)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Text(Formatters.peso(i.lineTotal),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              const Divider(height: 26),
              _amount(context, 'Subtotal', inv.subtotal),
              if (inv.discount > 0)
                _amount(context, 'Discount', -inv.discount,
                    color: scheme.onSurfaceVariant),
              _amount(context, 'Total', inv.total, bold: true),
              const SizedBox(height: 10),
              _sectionLabel(context, 'Payments (${payments.length})'),
              if (payments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.payments_outlined,
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text('No payments recorded yet.',
                          style: TextStyle(
                              fontSize: 13, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              for (final p in payments)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(p.method.icon,
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${p.method.label} · '
                                '${Formatters.date(p.date)}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            if (p.reference.isNotEmpty)
                              Text('Ref ${p.reference}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant)),
                            if (p.amountReceived != null &&
                                (p.changeGiven ?? 0) > 0)
                              Text(
                                  'Received ${Formatters.peso(p.amountReceived!)} · '
                                  'Change ${Formatters.peso(p.changeGiven!)}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant)),
                            if (p.note.isNotEmpty)
                              Text(p.note,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Text(Formatters.peso(p.amount),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3E9E6E))),
                    ],
                  ),
                ),
              const Divider(height: 26),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (inv.balance > 0 ? scheme.error : scheme.primary)
                      .withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Balance',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(Formatters.peso(inv.balance),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: inv.balance > 0
                                ? scheme.error
                                : scheme.primary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
        if (inv.balance > 0 && !inv.voided)
          FilledButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => RecordPaymentDialog(invoiceId: inv.id),
            ),
            icon: const Icon(Icons.payments_rounded, size: 18),
            label: const Text('Record Payment'),
          ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  Widget _meta(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _amount(BuildContext context, String label, double value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                  color: color)),
          Text(Formatters.peso(value),
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  fontSize: bold ? 16 : 14,
                  color: color)),
        ],
      ),
    );
  }
}
