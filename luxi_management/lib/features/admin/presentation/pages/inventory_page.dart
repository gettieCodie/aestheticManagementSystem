import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../models/product.dart';
import '../../state/admin_store.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_card.dart';
import 'page_scaffold.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();

    return AdminPageScaffold(
      title: 'Inventory Management',
      subtitle: 'Multi-branch inventory tracking',
      children: [
        StatRow(cards: [
          StatCard(
            label: 'Total Inventory Value',
            value: Formatters.peso(store.totalInventoryValue),
            icon: Icons.inventory_2_rounded,
          ),
          StatCard(
            label: 'Low Stock Items',
            value: '${store.lowStockCount}',
            icon: Icons.warning_amber_rounded,
            accent: AppColorsRef.warning,
          ),
          StatCard(
            label: 'Critical Stock',
            value: '${store.criticalCount}',
            icon: Icons.trending_down_rounded,
            accent: AppColorsRef.error,
          ),
          StatCard(
            label: 'Out of Stock',
            value: '${store.outOfStockCount}',
            icon: Icons.error_outline_rounded,
            accent: AppColorsRef.error,
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Products',
          icon: Icons.list_alt_rounded,
          action: FilledButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const _AddProductDialog(),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Product'),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 26,
              headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              columns: const [
                DataColumn(label: Text('Product')),
                DataColumn(label: Text('SKU')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Stock')),
                DataColumn(label: Text('Branch Allocation')),
                DataColumn(label: Text('Status')),
              ],
              rows: [
                for (final p in store.products) _row(context, p),
              ],
            ),
          ),
        ),
      ],
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
          Text(p.supplier,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
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
      DataCell(_statusBadge(p.status)),
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
  const _AddProductDialog();

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _category = TextEditingController();
  final _supplier = TextEditingController();
  final _unit = TextEditingController(text: 'pcs');
  final _price = TextEditingController();
  final _cost = TextEditingController();
  final _reorder = TextEditingController(text: '10');
  final _critical = TextEditingController(text: '5');

  @override
  void dispose() {
    for (final c in [
      _name, _sku, _category, _supplier, _unit, _price, _cost, _reorder, _critical
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final store = context.read<AdminStore>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await store.addProduct(Product(
        id: store.newProductId(),
        name: _name.text.trim(),
        sku: _sku.text.trim().isEmpty ? 'SKU-NEW' : _sku.text.trim(),
        category: _category.text.trim().isEmpty ? 'General' : _category.text.trim(),
        supplier: _supplier.text.trim(),
        unit: _unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim(),
        price: double.tryParse(_price.text) ?? 0,
        cost: double.tryParse(_cost.text) ?? 0,
        reorderLevel: int.tryParse(_reorder.text) ?? 10,
        criticalLevel: int.tryParse(_critical.text) ?? 5,
        branchStock: {for (final b in kBranches) b: 0},
      ));
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not add product: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Add Product'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_name, 'Product name', required: true),
                _twoUp(_field(_sku, 'SKU'), _field(_category, 'Category')),
                _field(_supplier, 'Supplier'),
                _twoUp(_field(_unit, 'Unit (pcs/bottles)'),
                    _field(_price, 'Sell price', number: true)),
                _twoUp(_field(_cost, 'Cost', number: true),
                    _field(_reorder, 'Reorder level', number: true)),
                _field(_critical, 'Critical level', number: true),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('New products start at 0 stock in all branches.',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Add')),
      ],
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
