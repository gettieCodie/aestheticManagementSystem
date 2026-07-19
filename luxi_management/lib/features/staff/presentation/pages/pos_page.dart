import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/formatters.dart';
import '../../../admin/models/product.dart' show kBranches;
import '../../../admin/models/promo_package.dart';
import '../../../admin/models/service_config.dart';
import '../../../admin/presentation/pages/page_scaffold.dart';
import '../../../admin/presentation/widgets/section_card.dart';
import '../../../admin/state/admin_store.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../billing/models/invoice.dart';
import '../../../billing/presentation/record_payment_dialog.dart';
import '../../../billing/state/billing_store.dart';
import '../../models/customer.dart';
import '../../state/staff_store.dart';
import 'scheduling_page.dart' show kTimeSlots;

enum _Mode { newSale, payments }

enum _SaleType { package, service }

enum _Plan { full, installment, perSession, billLater }

/// POS — a clean, cart-style checkout. Creates an Invoice, then records a
/// Payment. Packages, billing and payments stay distinct under the hood.
class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  _Mode _mode = _Mode.newSale;

  String? _customerId;
  _SaleType _saleType = _SaleType.package;
  bool _isPromo = true;
  PromoPackage? _promo;
  ServiceConfig? _service;
  String _branch = kBranches.first;
  bool _lockedBranch = false;

  final _customType = TextEditingController();
  final _customPrice = TextEditingController();
  final _customSessions = TextEditingController(text: '6');
  final _interval = TextEditingController(text: '7');
  final _discountPct = TextEditingController(text: '0');
  final _installment = TextEditingController();
  DateTime _startDate = DateTime.now();
  final Set<String> _aftercare = {};
  _Plan _plan = _Plan.full;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final b = context.read<AuthController>().currentUser?.branch;
    if (b != null) {
      _branch = b;
      _lockedBranch = true;
    }

    // If we arrived here from "Proceed to Payment", prefill client + service.
    final pending = context.read<StaffStore>().pendingCheckout;
    if (pending != null) {
      _mode = _Mode.newSale;
      _saleType = _SaleType.service;
      _customerId = pending.customerId;
      for (final s in context.read<AdminStore>().services) {
        if (s.name.toLowerCase() == pending.serviceName.toLowerCase()) {
          _service = s;
          break;
        }
      }
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => context.read<StaffStore>().clearPendingCheckout());
    }
  }

  @override
  void dispose() {
    for (final c in [
      _customType, _customPrice, _customSessions, _interval, _discountPct, _installment
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // --- Derived amounts ----------------------------------------------------
  int get _sessions => _saleType == _SaleType.service
      ? 1
      : (_isPromo ? (_promo?.sessionCount ?? 0) : (int.tryParse(_customSessions.text) ?? 0));

  double get _baseAmount {
    if (_saleType == _SaleType.service) return _service?.price ?? 0;
    return _isPromo ? (_promo?.fixedPrice ?? 0) : (double.tryParse(_customPrice.text) ?? 0);
  }

  String get _saleName {
    if (_saleType == _SaleType.service) return _service?.name ?? 'Service';
    if (_isPromo) return _promo?.name ?? 'Package';
    return _customType.text.trim().isEmpty ? 'Custom Package' : _customType.text.trim();
  }

  List<InvoiceLineItem> _cart(AdminStore admin) {
    final items = <InvoiceLineItem>[];
    if (_baseAmount > 0) {
      items.add(InvoiceLineItem(
          name: _saleName,
          type: _saleType == _SaleType.package ? 'package' : 'service',
          quantity: 1,
          unitPrice: _baseAmount));
    }
    for (final p in admin.products.where((p) => _aftercare.contains(p.id))) {
      items.add(InvoiceLineItem(name: p.name, type: 'product', quantity: 1, unitPrice: p.price));
    }
    return items;
  }

  List<DateTime> get _sessionDates {
    if (_saleType != _SaleType.package) return [];
    final interval = int.tryParse(_interval.text) ?? 7;
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    return [for (int i = 0; i < _sessions; i++) start.add(Duration(days: interval * i))];
  }

  double _payingNow(double total) {
    switch (_plan) {
      case _Plan.full:
        return total;
      case _Plan.installment:
        return (double.tryParse(_installment.text) ?? 0).clamp(0, total).toDouble();
      case _Plan.perSession:
        return _sessions > 0 ? (_baseAmount / _sessions) : 0;
      case _Plan.billLater:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: 'Point of Sale',
      subtitle: 'Sell packages or services and take payment',
      children: [
        SegmentedButton<_Mode>(
          segments: const [
            ButtonSegment(
                value: _Mode.newSale,
                icon: Icon(Icons.add_shopping_cart_rounded),
                label: Text('New Sale')),
            ButtonSegment(
                value: _Mode.payments,
                icon: Icon(Icons.account_balance_wallet_rounded),
                label: Text('Collect Payment')),
          ],
          selected: {_mode},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        const SizedBox(height: 20),
        if (_mode == _Mode.newSale) _newSale(context) else _payments(context),
      ],
    );
  }

  // --- New Sale (two-column checkout) -------------------------------------
  Widget _newSale(BuildContext context) {
    final admin = context.watch<AdminStore>();

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepCard(
          step: 1,
          title: 'Choose client',
          icon: Icons.person_rounded,
          child: _customerPicker(context),
        ),
        const SizedBox(height: 16),
        _stepCard(
          step: 2,
          title: 'Choose what to sell',
          icon: Icons.sell_rounded,
          child: _sellContent(admin),
        ),
        if (_saleType == _SaleType.package) ...[
          const SizedBox(height: 16),
          _stepCard(
            step: 3,
            title: 'Schedule sessions',
            icon: Icons.event_repeat_rounded,
            child: _schedule(),
          ),
        ],
        const SizedBox(height: 16),
        _stepCard(
          step: _saleType == _SaleType.package ? 4 : 3,
          title: 'Add aftercare products',
          icon: Icons.shopping_bag_rounded,
          optional: true,
          child: _aftercareGrid(admin),
        ),
      ],
    );

    final right = _orderSummary(context, admin);

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: left),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: right),
            ],
          );
        }
        return Column(children: [left, const SizedBox(height: 16), right]);
      },
    );
  }

  Widget _stepCard({
    required int step,
    required String title,
    required IconData icon,
    required Widget child,
    bool optional = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: scheme.primary,
                child: Text('$step',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              if (optional) ...[
                const SizedBox(width: 6),
                Text('(optional)',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _customerPicker(BuildContext context) {
    final staff = context.watch<StaffStore>();
    return InputDecorator(
      decoration: const InputDecoration(
          labelText: 'Client', prefixIcon: Icon(Icons.badge_outlined)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _customerId,
          isExpanded: true,
          hint: const Text('Search or select a client'),
          items: [
            for (final c in staff.customers)
              DropdownMenuItem(value: c.id, child: Text('${c.fullName} · ${c.clientId}')),
          ],
          onChanged: (v) => setState(() => _customerId = v),
        ),
      ),
    );
  }

  Widget _sellContent(AdminStore admin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<_SaleType>(
          segments: const [
            ButtonSegment(
                value: _SaleType.package,
                icon: Icon(Icons.card_membership_rounded),
                label: Text('Package')),
            ButtonSegment(
                value: _SaleType.service,
                icon: Icon(Icons.spa_rounded),
                label: Text('Single Service')),
          ],
          selected: {_saleType},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() {
            _saleType = s.first;
            if (_saleType == _SaleType.service && _plan == _Plan.perSession) {
              _plan = _Plan.full;
            }
          }),
        ),
        const SizedBox(height: 16),
        if (_saleType == _SaleType.package) _packageContent(admin) else _serviceContent(admin),
      ],
    );
  }

  Widget _packageContent(AdminStore admin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Promo')),
            ButtonSegment(value: false, label: Text('Custom')),
          ],
          selected: {_isPromo},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _isPromo = s.first),
        ),
        const SizedBox(height: 14),
        if (_isPromo)
          for (final p in admin.promoPackages)
            _selectTile(
              selected: _promo == p,
              title: p.name,
              subtitle: '${p.sessionCount} sessions',
              trailing: Formatters.peso(p.fixedPrice),
              onTap: () => setState(() => _promo = p),
            )
        else
          Column(children: [
            TextField(
              controller: _customType,
              decoration: const InputDecoration(labelText: 'Package name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _customPrice,
                  decoration: const InputDecoration(labelText: 'Total price (₱)'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _customSessions,
                  decoration: const InputDecoration(labelText: 'Sessions'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
          ]),
      ],
    );
  }

  Widget _serviceContent(AdminStore admin) {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Service'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ServiceConfig>(
          value: _service,
          isExpanded: true,
          hint: const Text('Choose a service'),
          items: [
            for (final s in admin.services)
              DropdownMenuItem(
                  value: s, child: Text('${s.name} · ${Formatters.peso(s.price)}')),
          ],
          onChanged: (v) => setState(() => _service = v),
        ),
      ),
    );
  }

  Widget _schedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _interval,
              decoration: const InputDecoration(
                  labelText: 'Every … days', prefixIcon: Icon(Icons.repeat_rounded)),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _branchField()),
        ]),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _startDate,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => _startDate = picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(
                labelText: 'Start date', prefixIcon: Icon(Icons.event_rounded)),
            child: Text(Formatters.date(_startDate)),
          ),
        ),
        if (_sessions > 0) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < _sessionDates.length && i < 60; i++)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('S${i + 1} · ${Formatters.date(_sessionDates[i])}'),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _branchField() {
    if (_lockedBranch) {
      return InputDecorator(
        decoration: const InputDecoration(labelText: 'Branch', isDense: true),
        child: Text(_branch),
      );
    }
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Branch', isDense: true),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _branch,
          isExpanded: true,
          items: [for (final b in kBranches) DropdownMenuItem(value: b, child: Text(b))],
          onChanged: (v) => setState(() => _branch = v ?? _branch),
        ),
      ),
    );
  }

  Widget _aftercareGrid(AdminStore admin) {
    final scheme = Theme.of(context).colorScheme;
    final products = admin.products.where((p) => p.price > 0).toList();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final p in products)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() =>
                _aftercare.contains(p.id) ? _aftercare.remove(p.id) : _aftercare.add(p.id)),
            child: Container(
              width: 180,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _aftercare.contains(p.id)
                    ? scheme.primary.withValues(alpha: 0.1)
                    : scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _aftercare.contains(p.id) ? scheme.primary : scheme.outlineVariant,
                  width: _aftercare.contains(p.id) ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _aftercare.contains(p.id)
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(Formatters.peso(p.price),
                            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // --- Order summary (the cart) -------------------------------------------
  Widget _orderSummary(BuildContext context, AdminStore admin) {
    final scheme = Theme.of(context).colorScheme;
    final staff = context.read<StaffStore>();
    final items = _cart(admin);
    final subtotal = items.fold<double>(0, (s, i) => s + i.lineTotal);
    final discountPct = double.tryParse(_discountPct.text) ?? 0;
    final discountAmt = subtotal * discountPct / 100;
    final total = (subtotal - discountAmt).clamp(0, double.infinity).toDouble();
    final payingNow = _payingNow(total);
    final balanceAfter = (total - payingNow).clamp(0, double.infinity);
    final ready = _customerId != null && _baseAmount > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.receipt_long_rounded, color: scheme.primary),
            const SizedBox(width: 8),
            Text('Order Summary',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Nothing added yet.',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            )
          else
            for (final i in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_itemIcon(i.type), size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(child: Text(i.name)),
                    Text(Formatters.peso(i.lineTotal),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          const Divider(height: 22),
          _row(context, 'Subtotal', Formatters.peso(subtotal)),
          Row(children: [
            const Text('Discount'),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: TextField(
                controller: _discountPct,
                decoration: const InputDecoration(suffixText: '%', isDense: true),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
              ),
            ),
            const Spacer(),
            Text('− ${Formatters.peso(discountAmt)}',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(Formatters.peso(total),
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18, color: scheme.primary)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('How is the client paying?',
              style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface)),
          const SizedBox(height: 10),
          _planOption(_Plan.full, Icons.check_circle_rounded, 'Pay in full',
              'Settle the entire amount now', Formatters.peso(total)),
          _planOption(_Plan.installment, Icons.schedule_rounded, 'Installment',
              'Pay part now, the rest later', null),
          if (_saleType == _SaleType.package)
            _planOption(_Plan.perSession, Icons.confirmation_number_rounded, 'Per session',
                'Pay one session at a time',
                _sessions > 0 ? Formatters.peso(_baseAmount / _sessions) : null),
          _planOption(_Plan.billLater, Icons.description_outlined, 'Bill later',
              'Create the invoice, collect later', null),
          if (_plan == _Plan.installment) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _installment,
              decoration: const InputDecoration(labelText: 'Amount paying now (₱)'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 12),
          _row(context, 'Paying now', Formatters.peso(payingNow), color: scheme.primary, bold: true),
          _row(context, 'Balance', Formatters.peso(balanceAfter),
              color: balanceAfter > 0 ? scheme.error : scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: ready && !_submitting
                  ? () => _complete(context, total, payingNow, staff)
                  : null,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.point_of_sale_rounded),
              label: Text(_submitting ? 'Processing…' : 'Complete Sale',
                  style: const TextStyle(fontSize: 16)),
            ),
          ),
          if (!ready)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Pick a client and something to sell first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }

  IconData _itemIcon(String type) {
    switch (type) {
      case 'package':
        return Icons.card_membership_rounded;
      case 'product':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.spa_rounded;
    }
  }

  Widget _planOption(_Plan plan, IconData icon, String title, String desc, String? amount) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _plan == plan;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _plan = plan),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? scheme.primary.withValues(alpha: 0.1) : scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(desc, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (amount != null)
                Text(amount, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _complete(
      BuildContext context, double total, double payingNow, StaffStore staff) async {
    if (_submitting) return;
    final customer = staff.customerById(_customerId);
    if (customer == null) return;
    final admin = context.read<AdminStore>();
    final staffName = context.read<AuthController>().currentUser?.fullName ?? 'Staff';
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _submitting = true);
    try {
      await _completeSale(context, total, payingNow, customer, admin, staffName, staff);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not complete sale: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _completeSale(
    BuildContext context,
    double total,
    double payingNow,
    Customer customer,
    AdminStore admin,
    String staffName,
    StaffStore staff,
  ) async {
    final billing = context.read<BillingStore>();
    final isPackage = _saleType == _SaleType.package;
    final items = _cart(admin);
    final discountPct = double.tryParse(_discountPct.text) ?? 0;
    final subtotal = items.fold<double>(0, (s, i) => s + i.lineTotal);

    final invoice = await billing.createInvoice(
      customerId: customer.id,
      customerName: customer.fullName,
      branch: _branch,
      staffName: staffName,
      items: items,
      discount: subtotal * discountPct / 100,
      plan: _plan == _Plan.full
          ? PaymentPlan.full
          : _plan == _Plan.installment
              ? PaymentPlan.installment
              : _plan == _Plan.perSession
                  ? PaymentPlan.perSession
                  : PaymentPlan.billLater,
      dueDate: _plan == _Plan.installment || _plan == _Plan.perSession
          ? DateTime.now().add(const Duration(days: 30))
          : null,
    );

    if (isPackage) {
      await staff.createPackage(
        customerId: customer.id,
        packageName: _saleName,
        totalSessions: _sessions,
        totalPrice: _baseAmount,
        paidAmount: payingNow,
        branch: _branch,
        sessionDates: _sessionDates,
        defaultTime: kTimeSlots.first,
        sessionIntervalDays: int.tryParse(_interval.text) ?? 7,
        invoiceId: invoice.id,
      );
    }

    if (payingNow > 0) {
      await billing.recordPayment(
        invoiceId: invoice.id,
        amount: payingNow,
        method: PaymentMethod.cash,
        staffName: staffName,
        note: _plan == _Plan.perSession ? 'Session 1' : 'Initial payment',
      );
    }

    if (!mounted) return;

    // Computed from the amounts already known locally, rather than reading
    // back from `invoice` — the stream that keeps BillingStore in sync
    // hasn't necessarily delivered the post-payment update yet.
    final paidTotal = payingNow.clamp(0, total);
    final balance = (total - paidTotal).clamp(0, double.infinity);

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text('Sale complete · ${invoice.id}'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${customer.fullName} — ${_saleName}'),
            const SizedBox(height: 8),
            Text('Total ${Formatters.peso(total)}'),
            Text('Paid ${Formatters.peso(paidTotal.toDouble())}'),
            Text('Balance ${Formatters.peso(balance.toDouble())}',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );

    setState(() {
      _customerId = null;
      _promo = null;
      _service = null;
      _aftercare.clear();
      _installment.clear();
      _customType.clear();
      _customPrice.clear();
      _discountPct.text = '0';
      _plan = _Plan.full;
    });
  }

  // --- Collect Payment ----------------------------------------------------
  Widget _payments(BuildContext context) {
    final billing = context.watch<BillingStore>();
    final open = billing.openInvoices;
    final scheme = Theme.of(context).colorScheme;

    return SectionCard(
      title: 'Open Balances (${open.length})',
      icon: Icons.account_balance_wallet_rounded,
      child: open.isEmpty
          ? Text('No outstanding balances — everyone is paid up.',
              style: TextStyle(color: scheme.onSurfaceVariant))
          : Column(children: [for (final inv in open) _openInvoiceRow(context, inv)]),
    );
  }

  Widget _openInvoiceRow(BuildContext context, Invoice inv) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${inv.customerName} · ${inv.id}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('Total ${Formatters.peso(inv.total)} · Paid ${Formatters.peso(inv.amountPaid)}',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Formatters.peso(inv.balance),
                  style: TextStyle(fontWeight: FontWeight.w800, color: scheme.error)),
              Text(inv.isOverdue ? 'Overdue' : inv.status.label,
                  style: TextStyle(
                      fontSize: 11,
                      color: inv.isOverdue ? scheme.error : scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history_rounded, size: 18),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => PaymentHistorySheet(invoiceId: inv.id),
            ),
          ),
          FilledButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => RecordPaymentDialog(invoiceId: inv.id),
            ),
            child: const Text('Collect'),
          ),
        ],
      ),
    );
  }

  Widget _selectTile({
    required bool selected,
    required String title,
    required String subtitle,
    required String trailing,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.1)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? scheme.primary : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 18, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Text(trailing,
                  style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
