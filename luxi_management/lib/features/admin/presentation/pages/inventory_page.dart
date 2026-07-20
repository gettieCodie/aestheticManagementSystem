import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/state/auth_controller.dart';
import '../../models/product.dart';
import '../../models/stock_movement.dart';
import '../../services/products_repository.dart';
import '../../state/admin_store.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_card.dart';
import 'inventory_mobile.dart';
import 'page_scaffold.dart';
import '../../../../core/widgets/app_toast.dart';

enum _Sort {
  name('Name A–Z'),
  sku('SKU'),
  quantity('Quantity (high → low)'),
  dateAdded('Date added (newest)');

  const _Sort(this.label);
  final String label;
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _search = TextEditingController();
  String? _category;
  String? _brand;
  String? _supplier;
  String? _branch;
  InventoryStatus? _status;
  bool _expiringSoon = false;
  _Sort _sort = _Sort.name;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _search.text.trim().isNotEmpty ||
      _category != null ||
      _brand != null ||
      _supplier != null ||
      _branch != null ||
      _status != null ||
      _expiringSoon;

  void _clearFilters() => setState(() {
        _search.clear();
        _category = null;
        _brand = null;
        _supplier = null;
        _branch = null;
        _status = null;
        _expiringSoon = false;
      });

  /// All filters compose — each one narrows the result of the previous.
  List<Product> _apply(List<Product> source) {
    final q = _search.text.trim().toLowerCase();
    var list = source.where((p) {
      if (q.isNotEmpty &&
          !p.name.toLowerCase().contains(q) &&
          !p.sku.toLowerCase().contains(q) &&
          !p.brand.toLowerCase().contains(q) &&
          !p.supplier.toLowerCase().contains(q)) {
        return false;
      }
      if (_category != null && p.category != _category) return false;
      if (_brand != null && p.brand != _brand) return false;
      if (_supplier != null && p.supplier != _supplier) return false;
      if (_status != null && p.status != _status) return false;
      if (_expiringSoon && !p.isExpiringSoon) return false;
      if (_branch != null && (p.branchStock[_branch] ?? 0) <= 0) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      switch (_sort) {
        case _Sort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _Sort.sku:
          return a.sku.compareTo(b.sku);
        case _Sort.quantity:
          return b.totalStock.compareTo(a.totalStock);
        case _Sort.dateAdded:
          final ad = a.createdAt ?? DateTime(2000);
          final bd = b.createdAt ?? DateTime(2000);
          return bd.compareTo(ad);
      }
    });
    return list;
  }

  List<String> _optionsOf(List<Product> products, String Function(Product) pick) {
    final set = products
        .map(pick)
        .where((v) => v.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return set;
  }

  @override
  Widget build(BuildContext context) {
    // Phones get the dedicated inventory module (dashboard → products →
    // details → adjust stock); desktop keeps the filterable table.
    if (Responsive.isMobile(context)) return const InventoryMobilePage();

    final store = context.watch<AdminStore>();
    final all = store.products;
    final products = _apply(all);

    // KPIs track the filtered set, not the whole catalog — same per-product
    // formulas AdminStore uses for its unfiltered totals.
    final filteredValue = products.fold<double>(0, (sum, p) => sum + p.inventoryValue);
    final filteredLowStock =
        products.where((p) => p.status == InventoryStatus.lowStock).length;
    final filteredCritical =
        products.where((p) => p.status == InventoryStatus.critical).length;
    final filteredOutOfStock =
        products.where((p) => p.status == InventoryStatus.outOfStock).length;

    return AdminPageScaffold(
      title: 'Inventory Management',
      subtitle: 'Multi-branch inventory tracking',
      children: [
        StatRow(cards: [
          StatCard(
            label: 'Total Inventory Value',
            value: Formatters.peso(filteredValue),
            icon: Icons.inventory_2_rounded,
          ),
          StatCard(
            label: 'Low Stock Items',
            value: '$filteredLowStock',
            icon: Icons.warning_amber_rounded,
            accent: AppColorsRef.warning,
          ),
          StatCard(
            label: 'Critical Stock',
            value: '$filteredCritical',
            icon: Icons.trending_down_rounded,
            accent: AppColorsRef.error,
          ),
          StatCard(
            label: 'Out of Stock',
            value: '$filteredOutOfStock',
            icon: Icons.error_outline_rounded,
            accent: AppColorsRef.error,
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        _filterBar(context, all),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: 'Products (${products.length}${products.length != all.length ? ' of ${all.length}' : ''})',
          icon: Icons.list_alt_rounded,
          action: FilledButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const _AddProductDialog(),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Product'),
          ),
          child: products.isEmpty
              ? (all.isEmpty
                  ? const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No products yet',
                      message: 'Add your first one to get started.',
                    )
                  : const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No products match these filters',
                    ))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 24,
                    headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    columns: const [
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('SKU')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Stock')),
                      DataColumn(label: Text('Branch Allocation')),
                      DataColumn(label: Text('Expiry')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: [for (final p in products) _row(context, p)],
                  ),
                ),
        ),
      ],
    );
  }

  /// Search + all six filters + sort. Every control composes with the others.
  ///
  /// Desktop only — `build` hands phones off to InventoryMobilePage first.
  Widget _filterBar(BuildContext context, List<Product> all) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search name, SKU, brand or supplier',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(() => _search.clear()),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 210,
                child: InputDecorator(
                  decoration:
                      const InputDecoration(labelText: 'Sort by', isDense: true),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<_Sort>(
                      value: _sort,
                      isExpanded: true,
                      items: [
                        for (final s in _Sort.values)
                          DropdownMenuItem(value: s, child: Text(s.label)),
                      ],
                      onChanged: (v) => setState(() => _sort = v ?? _sort),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _filterDropdown(
                label: 'Category',
                value: _category,
                options: _optionsOf(all, (p) => p.category),
                onChanged: (v) => setState(() => _category = v),
              ),
              _filterDropdown(
                label: 'Brand',
                value: _brand,
                options: _optionsOf(all, (p) => p.brand),
                onChanged: (v) => setState(() => _brand = v),
              ),
              _filterDropdown(
                label: 'Supplier',
                value: _supplier,
                options: _optionsOf(all, (p) => p.supplier),
                onChanged: (v) => setState(() => _supplier = v),
              ),
              _filterDropdown(
                label: 'Branch',
                value: _branch,
                options: kBranches,
                onChanged: (v) => setState(() => _branch = v),
              ),
              SizedBox(
                width: 170,
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Stock status', isDense: true),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<InventoryStatus?>(
                      value: _status,
                      isExpanded: true,
                      hint: const Text('All'),
                      items: [
                        const DropdownMenuItem<InventoryStatus?>(
                            value: null, child: Text('All')),
                        for (final s in InventoryStatus.values)
                          DropdownMenuItem(value: s, child: Text(s.label)),
                      ],
                      onChanged: (v) => setState(() => _status = v),
                    ),
                  ),
                ),
              ),
              FilterChip(
                label: const Text('Expiring soon'),
                avatar: const Icon(Icons.event_busy_rounded, size: 16),
                selected: _expiringSoon,
                onSelected: (v) => setState(() => _expiringSoon = v),
              ),
              if (_hasFilters)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                  label: const Text('Clear'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Nullable dropdown where `null` means "All".
  Widget _filterDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 170,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, isDense: true),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: options.contains(value) ? value : null,
            isExpanded: true,
            hint: const Text('All'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('All')),
              for (final o in options)
                DropdownMenuItem<String?>(value: o, child: Text(o)),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, Product p) {
    final scheme = Theme.of(context).colorScheme;
    return DataRow(cells: [
      DataCell(Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
            [
              if (p.brand.isNotEmpty) p.brand,
              if (p.supplier.isNotEmpty) p.supplier,
            ].join(' · '),
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      )),
      DataCell(Text(p.sku)),
      DataCell(_chip(context, p.category)),
      DataCell(Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${p.totalStock} ${p.unit}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('Reorder at ${p.reorderLevel}',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      )),
      DataCell(Text(
        p.branchStock.entries.map((e) => '${e.key} ${e.value}').join(' · '),
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      )),
      DataCell(p.expiryDate == null
          ? Text('—', style: TextStyle(color: scheme.onSurfaceVariant))
          : Text(
              Formatters.date(p.expiryDate!),
              style: TextStyle(
                fontSize: 12,
                fontWeight: p.isExpiringSoon ? FontWeight.w700 : FontWeight.w400,
                color: p.isExpiringSoon
                    ? AppColorsRef.warning
                    : scheme.onSurfaceVariant,
              ),
            )),
      DataCell(_statusBadge(p.status)),
      DataCell(Row(children: [
        IconButton(
          tooltip: 'Edit product',
          icon: const Icon(Icons.edit_outlined, size: 18),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => _AddProductDialog(existing: p),
          ),
        ),
        IconButton(
          tooltip: 'Adjust stock',
          icon: const Icon(Icons.inventory_2_outlined, size: 18),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => _AdjustStockDialog(product: p),
          ),
        ),
      ])),
    ]);
  }

  Widget _chip(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _statusBadge(InventoryStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: status.color)),
    );
  }
}

/// Minimal reference to palette colors without importing the theme file twice.
abstract final class AppColorsRef {
  static const warning = Color(0xFFE0A800);
  static const error = Color(0xFFE05252);
}

class _AddProductDialog extends StatefulWidget {
  const _AddProductDialog({this.existing});

  /// When set, the dialog edits this product in place instead of creating a
  /// new one — the opening-branch/quantity fields are hidden since stock
  /// changes go through Adjust Stock instead.
  final Product? existing;

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  bool get _isEdit => widget.existing != null;

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _price =
      TextEditingController(text: widget.existing == null ? '' : '${widget.existing!.price}');
  late final _cost =
      TextEditingController(text: widget.existing == null ? '' : '${widget.existing!.cost}');
  late final _reorder = TextEditingController(
      text: widget.existing == null ? '10' : '${widget.existing!.reorderLevel}');
  late final _critical = TextEditingController(
      text: widget.existing == null ? '5' : '${widget.existing!.criticalLevel}');
  final _openingQty = TextEditingController(text: '0');

  // Picked from dropdowns (with "＋ Add new…" to create an option on the fly).
  late String? _category = widget.existing?.category;
  late String? _brand = widget.existing?.brand;
  late String? _supplier = widget.existing?.supplier;
  late String _unit = widget.existing?.unit ?? 'pcs';
  String _branch = kBranches.first;
  late DateTime? _expiry = widget.existing?.expiryDate;
  bool _saving = false;

  static const List<String> _baseUnits = [
    'pcs', 'bottles', 'boxes', 'tubes', 'sachets', 'ml', 'liters', 'grams'
  ];

  @override
  void dispose() {
    for (final c in [_name, _price, _cost, _reorder, _critical, _openingQty]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Distinct existing values, so admins reuse options instead of retyping.
  List<String> _optionsOf(String Function(Product) pick) {
    final set = context
        .read<AdminStore>()
        .products
        .map(pick)
        .where((v) => v.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return set;
  }

  Future<String?> _promptNew(String label) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New $label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    controller.dispose();
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_category == null) {
      AppToast.error(context, 'Pick a category.');
      return;
    }
    final store = context.read<AdminStore>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        final existing = widget.existing!;
        await store.updateProduct(existing.copyWith(
          name: _name.text.trim(),
          category: _category!,
          brand: _brand ?? '',
          supplier: _supplier ?? '',
          unit: _unit,
          price: double.tryParse(_price.text) ?? 0,
          cost: double.tryParse(_cost.text) ?? 0,
          reorderLevel: int.tryParse(_reorder.text) ?? 10,
          criticalLevel: int.tryParse(_critical.text) ?? 5,
          expiryDate: _expiry,
        ));
        navigator.pop();
        AppToast.successOn(messenger, 'Product updated.');
        return;
      }

      final qty = int.tryParse(_openingQty.text) ?? 0;
      // SKU left blank on purpose — the repository assigns a unique one.
      final sku = await store.addProduct(Product(
        id: store.newProductId(),
        name: _name.text.trim(),
        sku: '',
        category: _category!,
        brand: _brand ?? '',
        supplier: _supplier ?? '',
        unit: _unit,
        price: double.tryParse(_price.text) ?? 0,
        cost: double.tryParse(_cost.text) ?? 0,
        reorderLevel: int.tryParse(_reorder.text) ?? 10,
        criticalLevel: int.tryParse(_critical.text) ?? 5,
        expiryDate: _expiry,
        branchStock: {for (final b in kBranches) b: b == _branch ? qty : 0},
      ));
      navigator.pop();
      AppToast.successOn(messenger, 'Product added — SKU $sku');
    } catch (e) {
      setState(() => _saving = false);
      AppToast.errorOn(messenger, 'Could not ${_isEdit ? 'update' : 'add'} product: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(_isEdit ? 'Edit Product' : 'Add Product'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field(_name, 'Product name', required: true),
                _twoUp(
                  _picker(
                    label: 'Category',
                    value: _category,
                    options: _optionsOf((p) => p.category),
                    onChanged: (v) => setState(() => _category = v),
                  ),
                  _picker(
                    label: 'Brand',
                    value: _brand,
                    options: _optionsOf((p) => p.brand),
                    onChanged: (v) => setState(() => _brand = v),
                  ),
                ),
                _twoUp(
                  _picker(
                    label: 'Supplier',
                    value: _supplier,
                    options: _optionsOf((p) => p.supplier),
                    onChanged: (v) => setState(() => _supplier = v),
                  ),
                  _picker(
                    label: 'Unit',
                    value: _unit,
                    options: {..._baseUnits, ..._optionsOf((p) => p.unit)}.toList()
                      ..sort(),
                    onChanged: (v) => setState(() => _unit = v ?? _unit),
                  ),
                ),
                // SKU is generated server-side so it can never collide.
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'SKU', isDense: true),
                    child: Row(children: [
                      Icon(Icons.lock_outline, size: 15, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        _isEdit
                            ? widget.existing!.sku
                            : _category == null
                                ? 'Auto-generated on save'
                                : '${ProductsRepository.skuPrefix(_category!)}-•••• (auto)',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ]),
                  ),
                ),
                _twoUp(_field(_price, 'Sell price', number: true),
                    _field(_cost, 'Cost', number: true)),
                _twoUp(_field(_reorder, 'Reorder level', number: true),
                    _field(_critical, 'Critical level', number: true)),
                if (!_isEdit)
                  _twoUp(
                    _picker(
                      label: 'Opening branch',
                      value: _branch,
                      options: kBranches,
                      allowCreate: false,
                      onChanged: (v) => setState(() => _branch = v ?? _branch),
                    ),
                    _field(_openingQty, 'Opening quantity', number: true),
                  ),
                _expiryField(scheme),
                if (_isEdit)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        'Use "Adjust Stock" from the table to change branch '
                        'quantities.',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isEdit ? 'Save Changes' : 'Add Product'),
        ),
      ],
    );
  }

  Widget _expiryField(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _expiry ?? DateTime.now().add(const Duration(days: 180)),
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now().add(const Duration(days: 3650)),
          );
          if (picked != null) setState(() => _expiry = picked);
        },
        child: InputDecorator(
          decoration: const InputDecoration(
              labelText: 'Expiry date (optional)', isDense: true),
          child: Text(
            _expiry == null ? 'Not set' : Formatters.date(_expiry!),
            style: TextStyle(
                color: _expiry == null ? scheme.onSurfaceVariant : null),
          ),
        ),
      ),
    );
  }

  /// Dropdown of existing values plus an inline "add new" option.
  Widget _picker({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    bool allowCreate = true,
  }) {
    const createSentinel = '__create__';
    final items = [...options];
    if (value != null && value.isNotEmpty && !items.contains(value)) {
      items.insert(0, value);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, isDense: true),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            hint: Text('Select $label'),
            items: [
              for (final o in items) DropdownMenuItem(value: o, child: Text(o)),
              if (allowCreate)
                const DropdownMenuItem(
                  value: createSentinel,
                  child: Text('＋ Add new…',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
            ],
            onChanged: (v) async {
              if (v == createSentinel) {
                final created = await _promptNew(label);
                if (created != null) onChanged(created);
                return;
              }
              onChanged(v);
            },
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool required = false, bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label, isDense: true),
        keyboardType: number ? TextInputType.number : TextInputType.text,
        inputFormatters:
            number ? [FilteringTextInputFormatter.digitsOnly] : null,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _twoUp(Widget a, Widget b) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: a),
        const SizedBox(width: 10),
        Expanded(child: b),
      ]);
}

/// Desktop counterpart to the mobile app's Adjust Stock page — same
/// [AdminStore.adjustStock] call, so the ledger and KPIs update identically
/// no matter which layout made the change.
class _AdjustStockDialog extends StatefulWidget {
  const _AdjustStockDialog({required this.product});
  final Product product;

  @override
  State<_AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends State<_AdjustStockDialog> {
  bool _adding = true;
  late String _branch = widget.product.branchStock.keys.isNotEmpty
      ? widget.product.branchStock.keys.first
      : kBranches.first;
  final _qty = TextEditingController(text: '1');
  String? _reason;
  final _remarks = TextEditingController();
  bool _busy = false;

  List<String> get _reasons => _adding ? kStockInReasons : kStockOutReasons;

  @override
  void dispose() {
    _qty.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final qty = int.tryParse(_qty.text) ?? 0;
    if (qty <= 0) {
      AppToast.error(context, 'Enter a quantity greater than zero.');
      return;
    }
    final admin = context.read<AdminStore>();
    final staffName = context.read<AuthController>().currentUser?.fullName ?? 'Admin';
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final p = widget.product;

    setState(() => _busy = true);
    try {
      await admin.adjustStock(
        product: p,
        branch: _branch,
        delta: _adding ? qty : -qty,
        reason: _reason ?? _reasons.first,
        remarks: _remarks.text.trim(),
        staffName: staffName,
      );
      navigator.pop();
      AppToast.successOn(messenger,
          '${_adding ? 'Added' : 'Deducted'} $qty ${p.unit} · ${p.name} · $_branch');
    } catch (e) {
      AppToast.errorOn(messenger, 'Could not adjust stock: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = widget.product;
    final currentQty = p.branchStock[_branch] ?? 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Adjust Stock'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${p.sku} · currently $currentQty ${p.unit} at $_branch',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: true,
                    icon: Icon(Icons.add_rounded),
                    label: Text('Add stock')),
                ButtonSegment(
                    value: false,
                    icon: Icon(Icons.remove_rounded),
                    label: Text('Remove stock')),
              ],
              selected: {_adding},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                _adding = s.first;
                _reason = null;
              }),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Branch', isDense: true),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _branch,
                        isExpanded: true,
                        items: [
                          for (final b in kBranches)
                            DropdownMenuItem(value: b, child: Text(b)),
                        ],
                        onChanged: (v) => setState(() => _branch = v ?? _branch),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _qty,
                    decoration: InputDecoration(
                        labelText: 'Quantity (${p.unit})', isDense: true),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Reason', isDense: true),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _reason ?? _reasons.first,
                  isExpanded: true,
                  items: [
                    for (final r in _reasons) DropdownMenuItem(value: r, child: Text(r)),
                  ],
                  onChanged: (v) => setState(() => _reason = v),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _remarks,
              decoration: const InputDecoration(labelText: 'Remarks (optional)', isDense: true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _confirm,
          child: _busy
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Confirm'),
        ),
      ],
    );
  }
}
