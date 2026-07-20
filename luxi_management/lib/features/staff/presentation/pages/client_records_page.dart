import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../admin/presentation/pages/page_scaffold.dart';
import '../../../admin/presentation/widgets/section_card.dart';
import '../../../admin/presentation/widgets/stat_card.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../billing/models/invoice.dart';
import '../../../billing/state/billing_store.dart';
import '../../models/customer.dart';
import '../../state/staff_store.dart';

enum _Filter { all, activePackages, withBalance }

enum _Sort { nameAsc, recentVisit, memberSince, outstanding }

double _outstandingFor(BillingStore b, String customerId) => b.invoices
    .where((i) => i.customerId == customerId && !i.voided)
    .fold(0.0, (s, i) => s + i.balance);

double _spentFor(BillingStore b, String customerId) => b.invoices
    .where((i) => i.customerId == customerId && !i.voided)
    .fold(0.0, (s, i) => s + i.amountPaid);

class ClientRecordsPage extends StatefulWidget {
  const ClientRecordsPage({super.key});

  @override
  State<ClientRecordsPage> createState() => _ClientRecordsPageState();
}

class _ClientRecordsPageState extends State<ClientRecordsPage> {
  static const int _pageSize = 10;

  final _search = TextEditingController();
  _Filter _filter = _Filter.all;
  _Sort _sort = _Sort.nameAsc;
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Any change to the query must send the reader back to the first page,
  /// otherwise a narrower result set leaves them on an empty page.
  void _resetPage() => _page = 0;

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<StaffStore>();
    final billing = context.watch<BillingStore>();
    final branch = context.watch<AuthController>().currentUser?.branch;

    final branchCustomers =
        staff.customers.where((c) => c.visibleTo(branch)).toList();

    var list = branchCustomers.where((c) => c.matches(_search.text)).toList();
    list = list.where((c) {
      switch (_filter) {
        case _Filter.all:
          return true;
        case _Filter.activePackages:
          return c.activePackages > 0;
        case _Filter.withBalance:
          return _outstandingFor(billing, c.id) > 0;
      }
    }).toList();

    list.sort((a, b) {
      switch (_sort) {
        case _Sort.nameAsc:
          return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
        case _Sort.recentVisit:
          final av = a.lastVisit ?? DateTime(2000);
          final bv = b.lastVisit ?? DateTime(2000);
          return bv.compareTo(av);
        case _Sort.memberSince:
          return b.memberSince.compareTo(a.memberSince);
        case _Sort.outstanding:
          return _outstandingFor(billing, b.id)
              .compareTo(_outstandingFor(billing, a.id));
      }
    });

    final withBalance = branchCustomers
        .where((c) => _outstandingFor(billing, c.id) > 0)
        .length;
    final activePkgs =
        branchCustomers.where((c) => c.activePackages > 0).length;

    // --- Pagination ---
    final pageCount = (list.length / _pageSize).ceil().clamp(1, 9999);
    final page = _page.clamp(0, pageCount - 1);
    final start = page * _pageSize;
    final visible = list.skip(start).take(_pageSize).toList();

    return AdminPageScaffold(
      title: 'Client Records',
      subtitle: 'Search, manage and follow up on your clients',
      children: [
        StatRow(cards: [
          StatCard(
              label: 'Total Clients',
              value: '${branchCustomers.length}',
              icon: Icons.people_alt_rounded),
          StatCard(
              label: 'Active Packages',
              value: '$activePkgs',
              icon: Icons.card_membership_rounded),
          StatCard(
              label: 'With Balance',
              value: '$withBalance',
              icon: Icons.account_balance_wallet_rounded,
              accent: const Color(0xFFE05252)),
        ]),
        const SizedBox(height: 16),
        _toolbar(context),
        const SizedBox(height: 12),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No clients match your search.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 2),
            child: Text(
              'Showing ${start + 1}–${start + visible.length} of ${list.length}',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        for (final c in visible)
          _ClientCard(
            customer: c,
            outstanding: _outstandingFor(billing, c.id),
          ),
        if (pageCount > 1) _pager(context, page, pageCount),
      ],
    );
  }

  /// Prev / page numbers / Next. Numbers collapse to a window of five so the
  /// row never overflows on a phone.
  Widget _pager(BuildContext context, int page, int pageCount) {
    final scheme = Theme.of(context).colorScheme;

    int windowStart = page - 2;
    if (windowStart < 0) windowStart = 0;
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
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              i == page ? FontWeight.w800 : FontWeight.w500,
                          color: i == page
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
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

  Widget _toolbar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMobile = Responsive.isMobile(context);

    final searchField = TextField(
      controller: _search,
      onChanged: (_) => setState(_resetPage),
      decoration: InputDecoration(
        hintText: isMobile ? 'Search clients' : 'Search by name, phone, or client ID',
        prefixIcon: const Icon(Icons.search_rounded),
        isDense: true,
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => setState(() {
                  _search.clear();
                  _resetPage();
                }),
              ),
      ),
    );

    final addButton = FilledButton.icon(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => const _ClientFormDialog(),
      ),
      icon: const Icon(Icons.person_add_alt_1, size: 18),
      label: const Text('Add Client'),
    );

    final sortDropdown = InputDecorator(
      decoration: const InputDecoration(labelText: 'Sort', isDense: true),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_Sort>(
          value: _sort,
          isExpanded: true,
          items: [
            for (final entry in _sortLabels.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (v) => setState(() {
            _sort = v ?? _sort;
            _resetPage();
          }),
        ),
      ),
    );

    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _filterChip('All', _Filter.all),
        _filterChip('Active packages', _Filter.activePackages),
        _filterChip('With balance', _Filter.withBalance),
        // On phones sort joins the chip row — a full-width labelled dropdown
        // gave one control more visual weight than all three filters combined.
        if (isMobile) _sortChip(),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      // Phones stack everything full width — side by side, the search box and
      // the sort dropdown were both squeezed to unreadable widths.
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 10),
                SizedBox(height: 44, child: addButton),
                const SizedBox(height: 12),
                chips,
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 12),
                    addButton,
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: chips),
                    const SizedBox(width: 8),
                    SizedBox(width: 180, child: sortDropdown),
                  ],
                ),
              ],
            ),
    );
  }

  static const Map<_Sort, String> _sortLabels = {
    _Sort.nameAsc: 'Name A–Z',
    _Sort.recentVisit: 'Recent visit',
    _Sort.memberSince: 'Newest member',
    _Sort.outstanding: 'Highest balance',
  };

  /// Sort rendered as an outlined chip so it matches the filters beside it.
  Widget _sortChip() {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<_Sort>(
      initialValue: _sort,
      onSelected: (v) => setState(() {
        _sort = v;
        _resetPage();
      }),
      itemBuilder: (_) => [
        for (final entry in _sortLabels.entries)
          PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert_rounded,
                size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(_sortLabels[_sort] ?? '',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, _Filter value) {
    return FilterChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() {
        _filter = value;
        _resetPage();
      }),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.customer, required this.outstanding});
  final Customer customer;
  final double outstanding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = customer;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ClientDetailPage(customerId: c.id),
          )),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: scheme.primary.withValues(alpha: 0.15),
                  child: Text(c.fullName.isNotEmpty ? c.fullName[0] : '?',
                      style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text('${c.clientId}  ·  ${c.phone}',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        if (c.activePackages > 0)
                          _tag(context, '${c.activePackages} active package(s)', scheme.primary),
                        if (outstanding > 0)
                          _tag(context, 'Balance ${Formatters.peso(outstanding)}', scheme.error),
                        _tag(
                            context,
                            c.lastVisit != null
                                ? 'Last visit ${Formatters.date(c.lastVisit!)}'
                                : 'No visits yet',
                            scheme.onSurfaceVariant),
                      ]),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

/// Add or edit a client.
class _ClientFormDialog extends StatefulWidget {
  const _ClientFormDialog({this.existing});
  final Customer? existing;

  @override
  State<_ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<_ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.fullName ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _email = TextEditingController(text: widget.existing?.email ?? '');
  late final _facebook = TextEditingController(text: widget.existing?.facebook ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _facebook.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) {
      AppToast.errorOn(messenger, 'Please fix the highlighted fields.');
      return;
    }
    final store = context.read<StaffStore>();
    final navigator = Navigator.of(context);
    try {
      if (widget.existing == null) {
        final branch = context.read<AuthController>().currentUser?.branch;
        await store.addCustomer(
          fullName: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          facebook: _facebook.text.trim(),
          notes: _notes.text.trim(),
          branch: branch,
        );
      } else {
        await store.updateCustomer(
          widget.existing!.id,
          fullName: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          facebook: _facebook.text.trim(),
          notes: _notes.text.trim(),
        );
      }
      navigator.pop();
      AppToast.successOn(
          messenger,
          widget.existing == null
              ? '${_name.text.trim()} added to client records.'
              : '${_name.text.trim()} updated.');
    } catch (e) {
      AppToast.errorOn(messenger, 'Could not save client: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(isEdit ? 'Edit Client' : 'Add Client'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_name, 'Full name', Icons.person_outline,
                    validator: Validate.all(
                        [Validate.required, Validate.minLength(2)])),
                _field(_phone, 'Phone', Icons.phone_outlined,
                    keyboard: TextInputType.phone,
                    validator:
                        Validate.all([Validate.required, Validate.phone])),
                _field(_email, 'Email', Icons.mail_outline,
                    keyboard: TextInputType.emailAddress,
                    validator: Validate.email),
                _field(_facebook, 'Facebook', Icons.facebook_outlined),
                _field(_notes, 'Notes', Icons.sticky_note_2_outlined, lines: 2),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: Text(isEdit ? 'Save' : 'Add')),
      ],
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    int lines = 1,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        maxLines: lines,
        keyboardType: keyboard,
        decoration: InputDecoration(
            labelText: label, prefixIcon: Icon(icon), isDense: true),
        validator: validator,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class ClientDetailPage extends StatelessWidget {
  const ClientDetailPage({super.key, required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<StaffStore>();
    final billing = context.watch<BillingStore>();
    final customer = staff.customerById(customerId);
    final scheme = Theme.of(context).colorScheme;

    if (customer == null) {
      return const Scaffold(body: Center(child: Text('Client not found')));
    }

    final outstanding = _outstandingFor(billing, customer.id);
    final spent = _spentFor(billing, customer.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.fullName),
        actions: [
          TextButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _ClientFormDialog(existing: customer),
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileHeader(customer: customer),
                const SizedBox(height: 16),
                _statsRow(context, customer, spent, outstanding),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Active Treatment Packages',
                  icon: Icons.trending_up_rounded,
                  child: Column(
                    children: [
                      for (final p in customer.packages)
                        _PackageCard(
                          package: p,
                          invoice: p.invoiceId == null
                              ? null
                              : billing.invoiceById(p.invoiceId!),
                        ),
                      if (customer.packages.isEmpty)
                        Text('No packages yet.',
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (customer.notes.trim().isNotEmpty) ...[
                  SectionCard(
                    title: 'Notes',
                    icon: Icons.sticky_note_2_outlined,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(customer.notes),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SectionCard(
                  title: 'Session Timeline',
                  icon: Icons.history_rounded,
                  child: Column(
                    children: [
                      for (final s in customer.sessions) _SessionTile(session: s),
                      if (customer.sessions.isEmpty)
                        Text('No sessions logged yet.',
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statsRow(
      BuildContext context, Customer c, double spent, double outstanding) {
    return StatRow(cards: [
      StatCard(label: 'Visits', value: '${c.visitCount}', icon: Icons.event_available_rounded),
      StatCard(label: 'Total Spent', value: Formatters.peso(spent), icon: Icons.payments_rounded),
      StatCard(
          label: 'Outstanding',
          value: Formatters.peso(outstanding),
          icon: Icons.account_balance_wallet_rounded,
          accent: const Color(0xFFE05252)),
      StatCard(
          label: 'Member Since',
          value: Formatters.date(c.memberSince),
          icon: Icons.card_membership_rounded),
    ]);
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: scheme.primary.withValues(alpha: 0.15),
            child: Text(customer.fullName.isNotEmpty ? customer.fullName[0] : '?',
                style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800, fontSize: 24)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                const SizedBox(height: 4),
                Wrap(spacing: 16, runSpacing: 4, children: [
                  _meta(context, Icons.badge_outlined, customer.clientId),
                  _meta(context, Icons.mail_outline, customer.email.isEmpty ? '—' : customer.email),
                  _meta(context, Icons.phone_outlined, customer.phone),
                  _meta(context, Icons.facebook_outlined,
                      customer.facebook.isEmpty ? '—' : 'Facebook'),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: scheme.onSurfaceVariant),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
    ]);
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.package, this.invoice});
  final TreatmentPackage package;
  final Invoice? invoice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = invoice?.total ?? package.totalPrice;
    final paid = invoice?.amountPaid ?? package.paidAmount;
    final balance = invoice?.balance ?? package.balance;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(package.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${package.sessionsLeft} sessions left',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${package.completedSessions} of ${package.totalSessions} sessions completed',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: package.progress,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 14),
          _payRow(context, 'Total Package', total, bold: true),
          _payRow(context, 'Paid', paid, color: scheme.primary),
          _payRow(context, 'Remaining Balance', balance, color: scheme.error, bold: true),
        ],
      ),
    );
  }

  Widget _payRow(BuildContext context, String label, double amount,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(Formatters.peso(amount),
              style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});
  final SessionRecord session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${session.serviceName} — Session ${session.sessionNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text('by ${session.staffName}',
                  style: TextStyle(fontSize: 12, color: scheme.primary)),
            ],
          ),
          const SizedBox(height: 2),
          Text(Formatters.date(session.date),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          if (session.productsUsed.isNotEmpty) ...[
            const SizedBox(height: 10),
            _label(context, 'Products Used'),
            Text(session.productsUsed.join(', ')),
          ],
          if (session.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            _label(context, 'Notes'),
            Text(session.notes),
          ],
          const SizedBox(height: 12),
          if (session.photoCount > 0)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => _PhotoAccessDialog(session: session),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${session.photoCount} progress photo(s) · password protected',
                        style: TextStyle(fontSize: 12.5, color: scheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.visibility_outlined, size: 16, color: scheme.primary),
                    const SizedBox(width: 4),
                    Text('View Photos',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: scheme.primary)),
                  ],
                ),
              ),
            )
          else
            Row(
              children: [
                Icon(Icons.lock_outline, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('No photos uploaded',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

/// Password-protected progress-photo viewer. Unlocks to a watermarked gallery.
class _PhotoAccessDialog extends StatefulWidget {
  const _PhotoAccessDialog({required this.session});
  final SessionRecord session;

  @override
  State<_PhotoAccessDialog> createState() => _PhotoAccessDialogState();
}

class _PhotoAccessDialogState extends State<_PhotoAccessDialog> {
  // Mock access password. In production this is a per-clinic / per-user gate.
  static const _password = 'luxi123';
  final _input = TextEditingController();
  bool _unlocked = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _tryUnlock() {
    if (_input.text.trim() == _password) {
      setState(() {
        _unlocked = true;
        _error = null;
      });
    } else {
      setState(() => _error = 'Incorrect password');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(children: [
        Icon(_unlocked ? Icons.photo_library_rounded : Icons.lock_rounded,
            color: scheme.primary, size: 20),
        const SizedBox(width: 8),
        Text('${widget.session.serviceName} — Session ${widget.session.sessionNumber}'),
      ]),
      content: SizedBox(
        width: 420,
        child: _unlocked ? _gallery(context) : _lock(context),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_unlocked ? 'Close' : 'Cancel')),
        if (!_unlocked)
          FilledButton(onPressed: _tryUnlock, child: const Text('Unlock')),
      ],
    );
  }

  Widget _lock(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('These progress photos are protected. Enter the access password to view.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
        const SizedBox(height: 16),
        TextField(
          controller: _input,
          obscureText: true,
          autofocus: true,
          onSubmitted: (_) => _tryUnlock(),
          decoration: InputDecoration(
            labelText: 'Access password',
            prefixIcon: const Icon(Icons.key_rounded),
            errorText: _error,
          ),
        ),
        const SizedBox(height: 8),
        Text('Demo password: $_password',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _gallery(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (int i = 0; i < widget.session.progressPhotos.length; i++)
          _photoTile(context, i, widget.session.progressPhotos[i]),
      ],
    );
  }

  Widget _photoTile(BuildContext context, int index, String url) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 122,
      height: 122,
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Center(child: Icon(Icons.broken_image_outlined, size: 34, color: scheme.primary)),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : Center(child: Icon(Icons.image_rounded, size: 34, color: scheme.primary)),
          ),
          // Watermark, like the "Luxuriskin Confidential" overlay in the mockup.
          Center(
            child: Transform.rotate(
              angle: -0.5,
              child: Text('Luxuriskin\nConfidential',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface.withValues(alpha: 0.25))),
            ),
          ),
          Positioned(
            bottom: 4,
            left: 6,
            child: Text('Photo ${index + 1}',
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
