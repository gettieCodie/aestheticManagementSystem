import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../admin/models/product.dart' show kBranches, Product;
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
import '../../../../core/widgets/app_toast.dart';

enum _Mode { newSale, payments }

enum _SaleType { package, service }

enum _Plan { full, perSession }

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
  final _reference = TextEditingController();
  final _received = TextEditingController();
  DateTime _startDate = DateTime.now();
  final Set<String> _aftercare = {};
  _Plan _plan = _Plan.full;
  PaymentMethod _payMethod = PaymentMethod.cash;
  bool _submitting = false;
  String? _payError;

  /// Set when this sale settles a completed appointment (via "Proceed to
  /// Payment") — carried onto the invoice and shown in the confirmation.
  DateTime? _appointmentDate;
  String? _appointmentTime;

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
      _appointmentDate = pending.appointmentDate;
      _appointmentTime = pending.appointmentTime;
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
      _customType, _customPrice, _customSessions, _interval, _discountPct,
      _reference, _received
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
      case _Plan.perSession:
        return _sessions > 0 ? (_baseAmount / _sessions) : 0;
    }
  }

  /// Every money figure the checkout needs, derived once so the order summary
  /// and the sticky mobile bar can never disagree.
  ({double subtotal, double discountAmt, double total, double payingNow, double balanceAfter, bool ready})
      _totals(AdminStore admin) {
    final items = _cart(admin);
    final subtotal = items.fold<double>(0, (s, i) => s + i.lineTotal);
    final discountPct = double.tryParse(_discountPct.text) ?? 0;
    final discountAmt = subtotal * discountPct / 100;
    final total = (subtotal - discountAmt).clamp(0, double.infinity).toDouble();
    final payingNow = _payingNow(total);
    return (
      subtotal: subtotal,
      discountAmt: discountAmt,
      total: total,
      payingNow: payingNow,
      balanceAfter: (total - payingNow).clamp(0, double.infinity).toDouble(),
      ready: _customerId != null && _baseAmount > 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    final page = AdminPageScaffold(
      title: 'Point of Sale',
      subtitle: 'Sell packages or services and take payment',
      children: [
        SegmentedButton<_Mode>(
          // Icons don't fit alongside the labels on a phone.
          segments: [
            ButtonSegment(
                value: _Mode.newSale,
                icon: isMobile ? null : const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('New Sale')),
            ButtonSegment(
                value: _Mode.payments,
                icon: isMobile
                    ? null
                    : const Icon(Icons.account_balance_wallet_rounded),
                label: Text(isMobile ? 'Collect' : 'Collect Payment')),
          ],
          selected: {_mode},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        const SizedBox(height: 20),
        if (_mode == _Mode.newSale) _newSale(context) else _payments(context),
      ],
    );

    if (!isMobile) return page;

    // On phones the checkout is a long scroll, so the total and the confirm
    // button ride along in a bar pinned above the navigation.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: page,
      bottomNavigationBar:
          _mode == _Mode.newSale ? _stickyCheckoutBar(context) : null,
    );
  }

  Widget _stickyCheckoutBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final admin = context.watch<AdminStore>();
    final staff = context.read<StaffStore>();
    final t = _totals(admin);

    return Padding(
      // Clears the floating bottom navigation bar.
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 92),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total',
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant)),
                  Text(Formatters.peso(t.total),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary)),
                  if (t.payingNow != t.total)
                    Text('Paying now ${Formatters.peso(t.payingNow)}',
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: t.ready && !_submitting
                    ? () => _complete(context, t.total, t.payingNow, staff)
                    : null,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.point_of_sale_rounded, size: 18),
                label: Text(_submitting ? 'Processing…' : 'Complete'),
              ),
            ),
          ],
        ),
      ),
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
        return Column(children: [
          left,
          const SizedBox(height: 16),
          right,
          // Room to scroll clear of the sticky checkout bar.
          if (Responsive.isMobile(context)) const SizedBox(height: 60),
        ]);
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
    final branch = context.watch<AuthController>().currentUser?.branch;
    final clients = staff.customers.where((c) => c.visibleTo(branch)).toList();
    return InputDecorator(
      decoration: const InputDecoration(
          labelText: 'Client', prefixIcon: Icon(Icons.badge_outlined)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _customerId,
          isExpanded: true,
          hint: const Text('Search or select a client'),
          items: [
            for (final c in clients)
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
    final products = admin.products.where((p) => p.price > 0).toList();

    // Phones get one full-width tile per row (a Column — a Wrap child can't
    // ask for infinite width). Wider screens keep the 180px tile grid.
    if (Responsive.isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in products)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _aftercareTile(p),
            ),
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final p in products) SizedBox(width: 180, child: _aftercareTile(p)),
      ],
    );
  }

  Widget _aftercareTile(Product p) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _aftercare.contains(p.id);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(
          () => selected ? _aftercare.remove(p.id) : _aftercare.add(p.id)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withValues(alpha: 0.1) : scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
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
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(Formatters.peso(p.price),
                      style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Order summary (the cart) -------------------------------------------
  Widget _orderSummary(BuildContext context, AdminStore admin) {
    final scheme = Theme.of(context).colorScheme;
    final staff = context.read<StaffStore>();
    final isMobile = Responsive.isMobile(context);
    final items = _cart(admin);
    final t = _totals(admin);
    final subtotal = t.subtotal;
    final discountAmt = t.discountAmt;
    final total = t.total;
    final payingNow = t.payingNow;
    final balanceAfter = t.balanceAfter;
    final ready = t.ready;

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
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
          _planOption(_Plan.full, Icons.check_circle_rounded, 'Full Payment',
              'Settle the entire amount now', Formatters.peso(total)),
          if (_saleType == _SaleType.package)
            _planOption(_Plan.perSession, Icons.confirmation_number_rounded, 'Session Payment',
                'Pay one session at a time',
                _sessions > 0 ? Formatters.peso(_baseAmount / _sessions) : null),
          if (payingNow > 0) _paymentDetails(payingNow),
          const SizedBox(height: 12),
          _row(context, 'Paying now', Formatters.peso(payingNow), color: scheme.primary, bold: true),
          _row(context, 'Balance', Formatters.peso(balanceAfter),
              color: balanceAfter > 0 ? scheme.error : scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          // On phones this lives in the sticky bar instead.
          if (!isMobile)
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

  double get _receivedValue => double.tryParse(_received.text) ?? 0;

  double _changeFor(double payingNow) =>
      (_receivedValue - payingNow).clamp(0, double.infinity).toDouble();

  /// Payment method picker + only the fields the chosen method needs.
  Widget _paymentDetails(double payingNow) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Text('Payment method',
            style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface)),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: const InputDecoration(isDense: true),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<PaymentMethod>(
              value: _payMethod,
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
                _payMethod = v ?? _payMethod;
                _payError = null;
              }),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_payMethod.isCash) ...[
          TextField(
            controller: _received,
            decoration: const InputDecoration(labelText: 'Amount received (₱)'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
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
                const Text('Change'),
                Text(Formatters.peso(_changeFor(payingNow)),
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: scheme.primary)),
              ],
            ),
          ),
        ] else
          TextField(
            controller: _reference,
            decoration: InputDecoration(
              labelText: '${_payMethod.label} reference number',
              hintText: 'e.g. 0123456789',
            ),
            onChanged: (_) => setState(() {}),
          ),
        if (_payError != null) ...[
          const SizedBox(height: 8),
          Text(_payError!, style: TextStyle(color: scheme.error, fontSize: 12)),
        ],
      ],
    );
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
    if (customer == null) {
      AppToast.error(context, 'Select a client before completing the sale.');
      return;
    }
    if (total <= 0) {
      AppToast.error(context, 'Add something to the order first.');
      return;
    }
    final discountPct = double.tryParse(_discountPct.text) ?? 0;
    if (discountPct > 100) {
      AppToast.error(context, 'Discount cannot exceed 100%.');
      return;
    }
    if (_saleType == _SaleType.package && _sessions <= 0) {
      AppToast.error(context, 'Set how many sessions this package includes.');
      return;
    }

    // Validate the payment details before touching Firestore.
    if (payingNow > 0) {
      if (_payMethod.requiresReference && _reference.text.trim().isEmpty) {
        setState(() =>
            _payError = 'Enter the ${_payMethod.label} reference number.');
        return;
      }
      if (_payMethod.isCash && _receivedValue < payingNow) {
        setState(() =>
            _payError = 'Amount received is less than the amount due.');
        return;
      }
      setState(() => _payError = null);
    }
    final admin = context.read<AdminStore>();
    final staffName = context.read<AuthController>().currentUser?.fullName ?? 'Staff';
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _submitting = true);
    try {
      await _completeSale(context, total, payingNow, customer, admin, staffName, staff);
    } catch (e) {
      AppToast.errorOn(messenger, 'Could not complete sale: $e');
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
      plan: _plan == _Plan.full ? PaymentPlan.full : PaymentPlan.perSession,
      dueDate: _plan == _Plan.perSession
          ? DateTime.now().add(const Duration(days: 30))
          : null,
      appointmentDate: _appointmentDate,
      appointmentTime: _appointmentTime,
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
        method: _payMethod,
        staffName: staffName,
        note: _plan == _Plan.perSession ? 'Session 1' : 'Initial payment',
        reference: _reference.text.trim(),
        amountReceived: _payMethod.isCash ? _receivedValue : null,
        changeGiven: _payMethod.isCash ? _changeFor(payingNow) : null,
      );
    }

    if (!mounted) return;

    // Computed from the amounts already known locally, rather than reading
    // back from `invoice` — the stream that keeps BillingStore in sync
    // hasn't necessarily delivered the post-payment update yet.
    final paidTotal = payingNow.clamp(0, total);
    final balance = (total - paidTotal).clamp(0, double.infinity);

    // Session Payment settles one session per payment — session 1 is paid at
    // checkout, so the next due date is the second scheduled session.
    final sessionDates = _sessionDates;
    final nextPaymentDate = _plan == _Plan.perSession && sessionDates.length > 1
        ? sessionDates[1]
        : null;

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
            Text('${customer.fullName} — $_saleName'),
            if (_appointmentDate != null)
              Text(
                  'Appointment ${Formatters.date(_appointmentDate!)} · '
                  '${_appointmentTime ?? ''}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('Total ${Formatters.peso(total)}'),
            Text('Paid ${Formatters.peso(paidTotal.toDouble())}'),
            if (payingNow > 0) ...[
              Text('Method ${_payMethod.label}'),
              if (_payMethod.isCash && _changeFor(payingNow) > 0)
                Text('Received ${Formatters.peso(_receivedValue)} · '
                    'Change ${Formatters.peso(_changeFor(payingNow))}'),
              if (_payMethod.requiresReference && _reference.text.trim().isNotEmpty)
                Text('Ref ${_reference.text.trim()}'),
            ],
            Text('Balance ${Formatters.peso(balance.toDouble())}',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (nextPaymentDate != null)
              Text('Next payment due ${Formatters.date(nextPaymentDate)}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600)),
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
      _appointmentDate = null;
      _appointmentTime = null;
      _aftercare.clear();
      _customType.clear();
      _customPrice.clear();
      _discountPct.text = '0';
      _plan = _Plan.full;
      _reference.clear();
      _received.clear();
      _payMethod = PaymentMethod.cash;
      _payError = null;
    });
  }

  // --- Collect Payment ----------------------------------------------------
  Widget _payments(BuildContext context) {
    final billing = context.watch<BillingStore>();
    final branch = context.watch<AuthController>().currentUser?.branch;
    final open = billing.openInvoices
        .where((i) => branch == null || i.branch == branch)
        .toList();
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

  /// The package this invoice bills, if any — matched by `invoiceId` on the
  /// customer's packages rather than a stored `packageId` on the invoice, so
  /// it works for packages created either at checkout or via "Complete
  /// Treatment Record".
  TreatmentPackage? _packageFor(StaffStore staff, Invoice inv) {
    final customer = staff.customerById(inv.customerId);
    if (customer == null) return null;
    for (final p in customer.packages) {
      if (p.invoiceId == inv.id) return p;
    }
    return null;
  }

  Widget _openInvoiceRow(BuildContext context, Invoice inv) {
    final scheme = Theme.of(context).colorScheme;
    final isMobile = Responsive.isMobile(context);
    final staff = context.watch<StaffStore>();
    final billing = context.watch<BillingStore>();

    // Session Payment invoices settle one session per payment — the next
    // unpaid session is simply how many payments have landed so far + 1.
    final package =
        inv.plan == PaymentPlan.perSession ? _packageFor(staff, inv) : null;
    final nextSession = package == null
        ? null
        : (billing.paymentsFor(inv.id).length + 1).clamp(1, package.totalSessions);

    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(inv.customerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(
            '${inv.id} · Total ${Formatters.peso(inv.total)} · '
            'Paid ${Formatters.peso(inv.amountPaid)}',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        if (nextSession != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Next: Session $nextSession of ${package!.totalSessions}',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: scheme.primary)),
          ),
      ],
    );

    final amount = Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(Formatters.peso(inv.balance),
            style: TextStyle(fontWeight: FontWeight.w800, color: scheme.error)),
        Text(inv.isOverdue ? 'Overdue' : inv.status.label,
            style: TextStyle(
                fontSize: 11,
                color: inv.isOverdue ? scheme.error : scheme.onSurfaceVariant)),
      ],
    );

    final historyButton = IconButton(
      tooltip: 'History',
      icon: const Icon(Icons.history_rounded, size: 18),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => PaymentHistorySheet(invoiceId: inv.id),
      ),
    );

    final collectButton = FilledButton(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => RecordPaymentDialog(invoiceId: inv.id),
      ),
      child: const Text('Collect'),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      // Four things in one row overflows a phone — stack them there.
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: amount),
                    historyButton,
                    const SizedBox(width: 4),
                    SizedBox(height: 40, child: collectButton),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: identity),
                amount,
                const SizedBox(width: 8),
                historyButton,
                collectButton,
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
