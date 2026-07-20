import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/state/auth_controller.dart';
import '../../models/product.dart';
import '../../models/stock_movement.dart';
import '../../state/admin_store.dart';

/// Phone inventory module: dashboard → products → details → adjust stock,
/// plus movement history and low-stock alerts.
///
/// Everything reads and writes through [AdminStore], so all of it is live
/// against Firestore exactly like the desktop inventory table.

// ===========================================================================
// Shared bits
// ===========================================================================

const _kRadius = 14.0;

BoxDecoration _cardDecoration(ColorScheme scheme, {Color? border}) =>
    BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(_kRadius),
      border: Border.all(
          color: border ?? scheme.outlineVariant.withValues(alpha: 0.7)),
    );

Widget _statusPill(InventoryStatus status) => _pill(status.label, status.color);

Widget _pill(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );

/// Standard phone scaffold: back arrow, title, optional trailing action.
class _MobileScaffold extends StatelessWidget {
  const _MobileScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
    this.bottomBar,
    this.floatingActionButton,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;
  final Widget? bottomBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            if (subtitle != null)
              Text(subtitle!,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [?action, const SizedBox(width: 8)],
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar,
      body: child,
    );
  }
}

/// Full-width primary button used at the foot of the action screens.
class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.label, required this.onPressed, this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: FilledButton(
            onPressed: busy ? null : onPressed,
            child: busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white),
                  )
                : Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// 1 · Inventory dashboard
// ===========================================================================

class InventoryMobilePage extends StatelessWidget {
  const InventoryMobilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminStore>();
    final scheme = Theme.of(context).colorScheme;
    final needs = admin.needsReplenishment;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Text('Inventory',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        Text('All branches',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 16),

        // Headline value
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(scheme),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total inventory value',
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Text(Formatters.peso(admin.totalInventoryValue),
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('${admin.products.length} products tracked',
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Status tiles
        Row(
          children: [
            Expanded(
                child: _tile(context, '${admin.lowStockCount}', 'Low stock',
                    InventoryStatus.lowStock.color)),
            const SizedBox(width: 10),
            Expanded(
                child: _tile(context, '${admin.criticalCount}',
                    'Critical stock', InventoryStatus.critical.color)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _tile(context, '${admin.outOfStockCount}',
                    'Out of stock', scheme.onSurfaceVariant)),
            const SizedBox(width: 10),
            Expanded(
                child: _tile(context, '${admin.expiringSoonCount}',
                    'Expiring soon', InventoryStatus.lowStock.color)),
          ],
        ),
        const SizedBox(height: 20),

        _navRow(
          context,
          icon: Icons.inventory_2_rounded,
          label: 'Products',
          trailing: '${admin.products.length}',
          onTap: () => _push(context, const ProductsListPage()),
        ),
        const SizedBox(height: 10),
        _navRow(
          context,
          icon: Icons.history_rounded,
          label: 'Movement history',
          trailing: '${admin.stockMovements.length}',
          onTap: () => _push(context, const MovementHistoryPage()),
        ),
        const SizedBox(height: 10),
        _navRow(
          context,
          icon: Icons.notification_important_rounded,
          label: 'Low stock alerts',
          trailing: '${needs.length}',
          onTap: () => _push(context, const LowStockAlertsPage()),
        ),

        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text('Needs replenishment',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            if (needs.length > 3)
              TextButton(
                onPressed: () => _push(context, const LowStockAlertsPage()),
                child: const Text('View all'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (needs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: _cardDecoration(scheme),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('Everything is well stocked.',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        for (final p in needs.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(_kRadius),
              child: InkWell(
                borderRadius: BorderRadius.circular(_kRadius),
                onTap: () => _push(context, ProductDetailsPage(productId: p.id)),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: _cardDecoration(scheme),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text(
                                '${p.totalStock} ${p.unit} left · '
                                'reorder at ${p.reorderLevel}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusPill(p.status),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tile(
      BuildContext context, String value, String label, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(_kRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _navRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String trailing,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(_kRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_kRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: _cardDecoration(scheme),
          child: Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              Text(trailing,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant)),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

// ===========================================================================
// 2 · Products list
// ===========================================================================

class ProductsListPage extends StatefulWidget {
  const ProductsListPage({super.key});

  @override
  State<ProductsListPage> createState() => _ProductsListPageState();
}

class _ProductsListPageState extends State<ProductsListPage> {
  final _search = TextEditingController();
  String? _category;
  String? _branch;
  InventoryStatus? _status;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminStore>();
    final scheme = Theme.of(context).colorScheme;
    final q = _search.text.trim().toLowerCase();

    final products = admin.products.where((p) {
      final matches = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.sku.toLowerCase().contains(q) ||
          p.brand.toLowerCase().contains(q);
      final categoryOk = _category == null || p.category == _category;
      final branchOk = _branch == null || (p.branchStock[_branch] ?? 0) > 0;
      final statusOk = _status == null || p.status == _status;
      return matches && categoryOk && branchOk && statusOk;
    }).toList();

    final categories = {
      for (final p in admin.products)
        if (p.category.isNotEmpty) p.category
    }.toList()
      ..sort();

    return _MobileScaffold(
      title: 'Products',
      subtitle: '${products.length} of ${admin.products.length}',
      floatingActionButton: FloatingActionButton(
        onPressed: () => _push(context, const ProductFormPage()),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        child: const Icon(Icons.add_rounded),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search by name or SKU',
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
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                _menuChip<String?>(
                  label: _category ?? 'All categories',
                  active: _category != null,
                  value: _category,
                  options: [null, ...categories],
                  labelOf: (v) => v ?? 'All categories',
                  onChanged: (v) => setState(() => _category = v),
                ),
                const SizedBox(width: 8),
                _menuChip<String?>(
                  label: _branch ?? 'All branches',
                  active: _branch != null,
                  value: _branch,
                  options: [null, ...kBranches],
                  labelOf: (v) => v ?? 'All branches',
                  onChanged: (v) => setState(() => _branch = v),
                ),
                const SizedBox(width: 8),
                _menuChip<InventoryStatus?>(
                  label: _status?.label ?? 'Status',
                  active: _status != null,
                  value: _status,
                  options: [null, ...InventoryStatus.values],
                  labelOf: (v) => v?.label ?? 'Any status',
                  onChanged: (v) => setState(() => _status = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? Center(
                    child: Text(
                        admin.products.isEmpty
                            ? 'No products yet. Tap + to add one.'
                            : 'No products match these filters.',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: products.length,
                    itemBuilder: (_, i) =>
                        _ProductRow(product: products[i]),
                  ),
          ),
        ],
      ),
    );
  }

  /// Chip that opens a menu — keeps six filters inside one scrolling row.
  Widget _menuChip<T>({
    required String label,
    required bool active,
    required T value,
    required List<T> options,
    required String Function(T) labelOf,
    required ValueChanged<T> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem<T>(value: o, child: Text(labelOf(o))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? scheme.primary : scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? scheme.onPrimary : scheme.onSurface)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded,
                size: 20,
                color: active ? scheme.onPrimary : scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// One product in the list. Swipe left for Edit / Delete, tap for details,
/// with quick stock-in / stock-out buttons inline.
class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = product;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kRadius),
        child: Dismissible(
          key: ValueKey(p.id),
          direction: DismissDirection.endToStart,
          // Never actually dismisses — the swipe just reveals the actions.
          confirmDismiss: (_) async {
            await _showRowActions(context, p);
            return false;
          },
          background: Container(
            color: scheme.primary,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: Icon(Icons.more_horiz_rounded, color: scheme.onPrimary),
          ),
          child: Material(
            color: scheme.surface,
            child: InkWell(
              onTap: () => _push(context, ProductDetailsPage(productId: p.id)),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: _cardDecoration(scheme),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                        const SizedBox(width: 8),
                        p.isExpiringSoon && p.status == InventoryStatus.inStock
                            ? _pill('Expiring Soon', InventoryStatus.lowStock.color)
                            : _statusPill(p.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                        '${p.sku} · ${p.category}'
                        '${p.expiryDate != null ? ' · exp ${Formatters.date(p.expiryDate!)}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${p.totalStock} ${p.unit}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 1),
                          child: Text('reorder at ${p.reorderLevel}',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: scheme.onSurfaceVariant)),
                        ),
                        const Spacer(),
                        _quickButton(context, Icons.add_rounded, 'Stock in',
                            InventoryStatus.inStock.color, () {
                          _push(context,
                              AdjustStockPage(productId: p.id, adding: true));
                        }),
                        const SizedBox(width: 8),
                        _quickButton(context, Icons.remove_rounded, 'Stock out',
                            scheme.primary, () {
                          _push(context,
                              AdjustStockPage(productId: p.id, adding: false));
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickButton(BuildContext context, IconData icon, String tooltip,
      Color color, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

Future<void> _showRowActions(BuildContext context, Product p) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit product'),
            onTap: () {
              Navigator.pop(sheet);
              _push(context, ProductFormPage(existing: p));
            },
          ),
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text('Adjust stock'),
            onTap: () {
              Navigator.pop(sheet);
              _push(context, AdjustStockPage(productId: p.id, adding: true));
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: scheme.error),
            title: Text('Delete product',
                style: TextStyle(color: scheme.error)),
            onTap: () {
              Navigator.pop(sheet);
              _confirmDelete(context, p);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

void _confirmDelete(BuildContext context, Product p) {
  final scheme = Theme.of(context).colorScheme;
  showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      icon: Icon(Icons.warning_amber_rounded, color: scheme.error, size: 32),
      title: const Text('Delete this product?', textAlign: TextAlign.center),
      content: Text(
        '"${p.name}" and its stock records will be permanently removed. '
        'This can\'t be undone.',
        textAlign: TextAlign.center,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style:
                      FilledButton.styleFrom(backgroundColor: scheme.error),
                  onPressed: () async {
                    final navigator = Navigator.of(dialog);
                    final messenger = ScaffoldMessenger.of(context);
                    final store = context.read<AdminStore>();
                    try {
                      await store.deleteProduct(p.id);
                      navigator.pop();
                      AppToast.successOn(messenger, '"${p.name}" deleted.');
                    } catch (e) {
                      navigator.pop();
                      AppToast.errorOn(messenger, 'Could not delete: $e');
                    }
                  },
                  child: const Text('Delete product'),
                ),
              ),
              TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('Cancel')),
            ],
          ),
        ),
      ],
    ),
  );
}

// ===========================================================================
// 3 · Product details
// ===========================================================================

class ProductDetailsPage extends StatelessWidget {
  const ProductDetailsPage({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminStore>();
    final scheme = Theme.of(context).colorScheme;
    final p = admin.productById(productId);

    if (p == null) {
      return const _MobileScaffold(
        title: 'Product details',
        child: Center(child: Text('This product no longer exists.')),
      );
    }

    final recent = admin.movementsFor(p.id).take(5).toList();

    return _MobileScaffold(
      title: 'Product details',
      action: TextButton(
        onPressed: () => _push(context, ProductFormPage(existing: p)),
        child: const Text('Edit'),
      ),
      bottomBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: () => _push(context,
                        AdjustStockPage(productId: p.id, adding: true)),
                    child: const Text('Adjust stock'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => _push(
                        context, MovementHistoryPage(productId: p.id)),
                    child: const Text('View history'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(scheme),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                    '${p.sku}${p.category.isNotEmpty ? ' · ${p.category}' : ''}',
                    style: TextStyle(
                        fontSize: 12.5, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                _statusPill(p.status),
                const Divider(height: 26),
                Row(
                  children: [
                    Expanded(
                        child: _field(context, 'On hand',
                            '${p.totalStock} ${p.unit}')),
                    Expanded(
                        child: _field(context, 'Reorder level',
                            '${p.reorderLevel} ${p.unit}')),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                        child: _field(
                            context, 'Unit price', Formatters.peso(p.price))),
                    Expanded(
                      child: _field(
                        context,
                        'Expiration',
                        p.expiryDate == null
                            ? '—'
                            : Formatters.date(p.expiryDate!),
                        color: p.isExpiringSoon
                            ? InventoryStatus.lowStock.color
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                        child: _field(context, 'Supplier',
                            p.supplier.isEmpty ? '—' : p.supplier)),
                    Expanded(
                        child: _field(context, 'Brand',
                            p.brand.isEmpty ? '—' : p.brand)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Branch allocation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(scheme),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Branch allocation',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 6),
                for (final b in kBranches)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Expanded(child: Text(b)),
                        Text('${p.branchStock[b] ?? 0}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Recent movements
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(scheme),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recent transactions',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                if (recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No stock movements recorded yet.',
                        style: TextStyle(
                            fontSize: 13, color: scheme.onSurfaceVariant)),
                  ),
                for (final m in recent) _MovementRow(movement: m, dense: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(BuildContext context, String label, String value,
      {Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 14.5, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

// ===========================================================================
// 4 · Adjust stock
// ===========================================================================

class AdjustStockPage extends StatefulWidget {
  const AdjustStockPage({
    super.key,
    required this.productId,
    required this.adding,
  });

  final String productId;
  final bool adding;

  @override
  State<AdjustStockPage> createState() => _AdjustStockPageState();
}

class _AdjustStockPageState extends State<AdjustStockPage> {
  late bool _adding = widget.adding;
  late String _branch;
  int _qty = 1;
  String? _reason;
  final _remarks = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Staff are locked to their branch; admins default to the first.
    _branch = context.read<AuthController>().currentUser?.branch ?? kBranches.first;
  }

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  List<String> get _reasons => _adding ? kStockInReasons : kStockOutReasons;

  Future<void> _confirm(Product p) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final admin = context.read<AdminStore>();
    final staffName =
        context.read<AuthController>().currentUser?.fullName ?? 'Staff';

    setState(() => _busy = true);
    try {
      await admin.adjustStock(
        product: p,
        branch: _branch,
        delta: _adding ? _qty : -_qty,
        reason: _reason ?? _reasons.first,
        remarks: _remarks.text.trim(),
        staffName: staffName,
      );
      navigator.pop();
      AppToast.successOn(
          messenger,
          '${_adding ? 'Added' : 'Deducted'} $_qty ${p.unit} '
          '· ${p.name} · $_branch');
    } catch (e) {
      AppToast.errorOn(messenger, 'Could not adjust stock: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminStore>();
    final scheme = Theme.of(context).colorScheme;
    final p = admin.productById(widget.productId);

    if (p == null) {
      return const _MobileScaffold(
        title: 'Adjust stock',
        child: Center(child: Text('This product no longer exists.')),
      );
    }

    final onHand = p.branchStock[_branch] ?? 0;
    final resulting = _adding ? onHand + _qty : (onHand - _qty).clamp(0, 1 << 30);
    final exceeds = !_adding && _qty > onHand;

    return _MobileScaffold(
      title: 'Adjust stock',
      bottomBar: _BottomAction(
        label: 'Confirm adjustment',
        busy: _busy,
        onPressed: _qty <= 0 || exceeds ? null : () => _confirm(p),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardDecoration(scheme),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                Text('On hand: $onHand ${p.unit} · $_branch',
                    style: TextStyle(
                        fontSize: 12.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Direction
          Row(
            children: [
              Expanded(child: _directionButton(true, 'Add stock', scheme)),
              const SizedBox(width: 10),
              Expanded(child: _directionButton(false, 'Deduct stock', scheme)),
            ],
          ),
          const SizedBox(height: 22),

          Center(
            child: Text('Quantity',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stepButton(Icons.remove_rounded,
                  _qty > 1 ? () => setState(() => _qty--) : null, scheme),
              SizedBox(
                width: 120,
                child: Text(
                  '${_adding ? '+' : '−'}$_qty',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: exceeds ? scheme.error : scheme.onSurface,
                  ),
                ),
              ),
              _stepButton(Icons.add_rounded, () => setState(() => _qty++),
                  scheme, filled: true),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              exceeds
                  ? 'Only $onHand ${p.unit} on hand at $_branch'
                  : 'New on-hand: $resulting ${p.unit}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: exceeds ? scheme.error : scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),

          _label(context, 'Branch'),
          InputDecorator(
            decoration: const InputDecoration(isDense: true),
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
          const SizedBox(height: 14),

          _label(context, 'Reason'),
          InputDecorator(
            decoration: const InputDecoration(isDense: true),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _reasons.contains(_reason) ? _reason : _reasons.first,
                isExpanded: true,
                items: [
                  for (final r in _reasons)
                    DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged: (v) => setState(() => _reason = v),
              ),
            ),
          ),
          const SizedBox(height: 14),

          _label(context, 'Remarks'),
          TextField(
            controller: _remarks,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'e.g. DR #2231 from Premium Essentials'),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );

  Widget _directionButton(bool adding, String label, ColorScheme scheme) {
    final selected = _adding == adding;
    return SizedBox(
      height: 46,
      child: selected
          ? FilledButton(
              onPressed: () => setState(() {
                _adding = adding;
                _reason = null;
              }),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: () => setState(() {
                _adding = adding;
                _reason = null;
              }),
              child: Text(label,
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap, ColorScheme scheme,
      {bool filled = false}) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Material(
        color: filled ? scheme.primary : scheme.surface,
        shape: CircleBorder(
            side: BorderSide(
                color: filled ? scheme.primary : scheme.outlineVariant)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(icon,
              color: filled ? scheme.onPrimary : scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

// ===========================================================================
// 5 · Add / edit product
// ===========================================================================

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key, this.existing});
  final Product? existing;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _price =
      TextEditingController(text: widget.existing?.price.toStringAsFixed(0) ?? '');
  late final _cost =
      TextEditingController(text: widget.existing?.cost.toStringAsFixed(0) ?? '');
  late final _stock = TextEditingController(text: '0');
  late final _reorder = TextEditingController(
      text: '${widget.existing?.reorderLevel ?? 10}');
  late final _critical = TextEditingController(
      text: '${widget.existing?.criticalLevel ?? 5}');
  late final _brand = TextEditingController(text: widget.existing?.brand ?? '');
  late final _supplier =
      TextEditingController(text: widget.existing?.supplier ?? '');

  late String _category = widget.existing?.category ?? 'Skincare';
  late String _unit = widget.existing?.unit ?? 'pcs';
  late DateTime? _expiry = widget.existing?.expiryDate;
  late String _branch = kBranches.first;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    for (final c in [
      _name, _price, _cost, _stock, _reorder, _critical, _brand, _supplier
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);

    if (!(_formKey.currentState?.validate() ?? false)) {
      AppToast.errorOn(messenger, 'Please fix the highlighted fields.');
      return;
    }

    // Cross-field rules the per-field validators can't express.
    final reorder = int.tryParse(_reorder.text) ?? 0;
    final critical = int.tryParse(_critical.text) ?? 0;
    if (critical > reorder) {
      AppToast.errorOn(
          messenger, 'Critical level must be at or below the reorder level.');
      return;
    }
    final price = double.tryParse(_price.text) ?? 0;
    final cost = double.tryParse(_cost.text) ?? 0;
    if (cost > price && price > 0) {
      AppToast.errorOn(
          messenger, 'Cost is higher than the selling price — check the values.');
      return;
    }

    final admin = context.read<AdminStore>();
    final navigator = Navigator.of(context);

    setState(() => _busy = true);
    try {
      if (_isEdit) {
        final old = widget.existing!;
        // Built directly rather than via copyWith: that helper falls back to
        // the old value on null, so clearing the expiry date would silently
        // keep the previous one.
        //
        // Stock is deliberately not editable here — Adjust stock is the only
        // way quantities change, so the ledger always matches reality.
        await admin.updateProduct(Product(
          id: old.id,
          name: _name.text.trim(),
          sku: old.sku,
          category: _category,
          supplier: _supplier.text.trim(),
          unit: _unit,
          price: double.tryParse(_price.text) ?? 0,
          cost: double.tryParse(_cost.text) ?? 0,
          reorderLevel: int.tryParse(_reorder.text) ?? 0,
          criticalLevel: int.tryParse(_critical.text) ?? 0,
          brand: _brand.text.trim(),
          expiryDate: _expiry,
          branchStock: old.branchStock,
          createdAt: old.createdAt,
        ));
      } else {
        final initial = int.tryParse(_stock.text) ?? 0;
        await admin.addProduct(Product(
          id: admin.newProductId(),
          name: _name.text.trim(),
          sku: '', // repository assigns a unique category-based SKU
          category: _category,
          supplier: _supplier.text.trim(),
          unit: _unit,
          price: double.tryParse(_price.text) ?? 0,
          cost: double.tryParse(_cost.text) ?? 0,
          reorderLevel: int.tryParse(_reorder.text) ?? 0,
          criticalLevel: int.tryParse(_critical.text) ?? 0,
          brand: _brand.text.trim(),
          expiryDate: _expiry,
          branchStock: {
            for (final b in kBranches) b: b == _branch ? initial : 0,
          },
        ));
      }
      navigator.pop();
      AppToast.successOn(
          messenger,
          _isEdit
              ? '"${_name.text.trim()}" updated.'
              : '"${_name.text.trim()}" added to inventory.');
    } catch (e) {
      AppToast.errorOn(messenger, 'Could not save product: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminStore>();
    final categories = {
      'Skincare', 'Treatment', 'Serum', 'Consumable',
      ...admin.products.map((p) => p.category).where((c) => c.isNotEmpty),
      _category,
    }.toList()
      ..sort();
    final units = {'pcs', 'bottles', 'boxes', 'tubes', 'ml', _unit}.toList()
      ..sort();
    final suppliers = admin.products
        .map((p) => p.supplier)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return _MobileScaffold(
      title: _isEdit ? 'Edit product' : 'Add product',
      bottomBar: _BottomAction(
        label: _isEdit ? 'Save changes' : 'Save product',
        busy: _busy,
        onPressed: _save,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            _label('Product name'),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration:
                  const InputDecoration(hintText: 'e.g. Hydrating Toner'),
              validator: Validate.all([Validate.required, Validate.minLength(2)]),
            ),
            const SizedBox(height: 14),
            if (_isEdit) ...[
              _label('SKU'),
              InputDecorator(
                decoration: const InputDecoration(isDense: true),
                child: Text(widget.existing!.sku),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                Expanded(
                  child: _dropdownField('Category', _category, categories,
                      (v) => setState(() => _category = v)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dropdownField(
                      'Unit', _unit, units, (v) => setState(() => _unit = v)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _numberField('Unit price (₱)', _price,
                      validator: Validate.all([
                        Validate.required,
                        Validate.money(min: 1, label: 'Price'),
                      ])),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numberField('Cost (₱)', _cost,
                      validator: Validate.money(label: 'Cost')),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _numberField('Reorder level', _reorder,
                      validator: Validate.all([
                        Validate.required,
                        Validate.number(max: 100000, label: 'Reorder level'),
                      ])),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numberField('Critical level', _critical,
                      validator: Validate.number(
                          max: 100000, label: 'Critical level')),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!_isEdit) ...[
              Row(
                children: [
                  Expanded(
                    child: _numberField('Initial stock', _stock,
                        validator: Validate.number(
                            max: 1000000, label: 'Initial stock')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dropdownField('Assign to branch', _branch,
                        kBranches, (v) => setState(() => _branch = v)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            _label('Brand'),
            TextFormField(
              controller: _brand,
              decoration: const InputDecoration(hintText: 'Optional'),
            ),
            const SizedBox(height: 14),
            _label('Supplier'),
            TextFormField(
              controller: _supplier,
              decoration: InputDecoration(
                hintText: 'Optional',
                suffixIcon: suppliers.isEmpty
                    ? null
                    : PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down_rounded),
                        onSelected: (v) => setState(() => _supplier.text = v),
                        itemBuilder: (_) => [
                          for (final s in suppliers)
                            PopupMenuItem(value: s, child: Text(s)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),
            _label('Expiration date'),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _expiry ??
                      DateTime.now().add(const Duration(days: 365)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                );
                if (picked != null) setState(() => _expiry = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  isDense: true,
                  suffixIcon: _expiry == null
                      ? const Icon(Icons.event_rounded, size: 20)
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => setState(() => _expiry = null),
                        ),
                ),
                child: Text(
                    _expiry == null ? 'None' : Formatters.date(_expiry!)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );

  Widget _numberField(String label, TextEditingController controller,
      {String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(isDense: true, hintText: '0'),
          validator: validator,
        ),
      ],
    );
  }

  Widget _dropdownField(String label, String value, List<String> options,
      ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        InputDecorator(
          decoration: const InputDecoration(isDense: true),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: options.contains(value) ? value : options.first,
              isExpanded: true,
              items: [
                for (final o in options)
                  DropdownMenuItem(value: o, child: Text(o)),
              ],
              onChanged: (v) => onChanged(v ?? value),
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// 6 · Movement history
// ===========================================================================

class MovementHistoryPage extends StatefulWidget {
  const MovementHistoryPage({super.key, this.productId});

  /// When set, shows only this product's movements.
  final String? productId;

  @override
  State<MovementHistoryPage> createState() => _MovementHistoryPageState();
}

class _MovementHistoryPageState extends State<MovementHistoryPage> {
  MovementType? _filter;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminStore>();
    final scheme = Theme.of(context).colorScheme;

    var list = widget.productId == null
        ? admin.stockMovements
        : admin.movementsFor(widget.productId!);
    if (_filter != null) {
      list = list.where((m) => m.type == _filter).toList();
    }

    // Group by calendar day, newest first (the list already arrives sorted).
    final groups = <DateTime, List<StockMovement>>{};
    for (final m in list) {
      final day = DateTime(m.date.year, m.date.month, m.date.day);
      groups.putIfAbsent(day, () => []).add(m);
    }

    return _MobileScaffold(
      title: 'Movement history',
      subtitle: widget.productId == null ? null : 'This product',
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                _chip('All', null),
                const SizedBox(width: 8),
                _chip('Stock in', MovementType.stockIn),
                const SizedBox(width: 8),
                _chip('Stock out', MovementType.stockOut),
                const SizedBox(width: 8),
                _chip('Adjustments', MovementType.adjustment),
              ],
            ),
          ),
          Expanded(
            child: groups.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No stock movements yet. Adjusting a product\'s '
                        'stock records an entry here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      for (final entry in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 10, 0, 8),
                          child: Text(_dayLabel(entry.key).toUpperCase(),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: scheme.onSurfaceVariant)),
                        ),
                        for (final m in entry.value) _MovementRow(movement: m),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today · ${Formatters.date(day)}';
    if (diff == 1) return 'Yesterday · ${Formatters.date(day)}';
    return Formatters.date(day);
  }

  Widget _chip(String label, MovementType? type) {
    final scheme = Theme.of(context).colorScheme;
    final active = _filter == type;
    return GestureDetector(
      onTap: () => setState(() => _filter = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: active ? scheme.primary : scheme.outlineVariant),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? scheme.onPrimary : scheme.onSurface)),
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement, this.dense = false});
  final StockMovement movement;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = movement;
    final positive = m.delta > 0;

    final detail = [
      Formatters.time(m.date),
      if (m.branch.isNotEmpty) m.branch,
      if (m.staffName.isNotEmpty) 'by ${m.staffName}',
      if (m.remarks.isNotEmpty) m.remarks else if (m.reason.isNotEmpty) m.reason,
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 8 : 10),
      child: Container(
        padding: EdgeInsets.all(dense ? 10 : 14),
        decoration: dense
            ? null
            : _cardDecoration(scheme),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: m.type.color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(m.type.icon, size: 18, color: m.type.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${m.type.label} · ${m.productName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13.5)),
                  Text(detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(m.signedLabel,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: positive
                        ? InventoryStatus.inStock.color
                        : scheme.error)),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 7 · Low stock alerts
// ===========================================================================

class LowStockAlertsPage extends StatelessWidget {
  const LowStockAlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminStore>();

    final needs = admin.needsReplenishment;
    final expiring = admin.products
        .where((p) => p.isExpiringSoon && p.status == InventoryStatus.inStock)
        .toList();
    final total = needs.length + expiring.length;

    return _MobileScaffold(
      title: 'Low stock alerts',
      subtitle: total == 0
          ? 'Nothing needs attention'
          : '$total product(s) need attention',
      child: total == 0
          ? const Center(
              child: EmptyState(
                icon: Icons.check_circle_outline,
                title: 'All stocked up',
                message: 'Every product is above its reorder level.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                for (final p in needs) _AlertCard(product: p),
                for (final p in expiring)
                  _AlertCard(product: p, expiringOnly: true),
              ],
            ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.product, this.expiringOnly = false});
  final Product product;
  final bool expiringOnly;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = product;
    final color =
        expiringOnly ? InventoryStatus.lowStock.color : p.status.color;
    final ratio = p.reorderLevel <= 0
        ? 1.0
        : (p.totalStock / p.reorderLevel).clamp(0.0, 1.0);

    final branches = p.branchStock.entries
        .where((e) => e.value <= 0 || e.value <= p.reorderLevel)
        .map((e) => e.key)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(_kRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(_kRadius),
          onTap: () => _push(context, ProductDetailsPage(productId: p.id)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_kRadius),
              // Severity stripe down the leading edge.
              border: Border(
                left: BorderSide(color: color, width: 4),
                top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.7)),
                right: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.7)),
                bottom: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.7)),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    const SizedBox(width: 8),
                    _pill(
                        expiringOnly ? 'Expiring Soon' : p.status.label, color),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  expiringOnly
                      ? '${p.totalStock} ${p.unit} expire '
                          '${p.expiryDate == null ? 'soon' : Formatters.date(p.expiryDate!)}'
                          ' · prioritise in POS & treatments'
                      : '${p.totalStock} of ${p.reorderLevel} reorder level'
                          '${branches.isEmpty ? '' : ' · ${branches.join(', ')}'}',
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                if (!expiringOnly) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      color: color,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      height: 36,
                      child: FilledButton.icon(
                        onPressed: () => _push(context,
                            AdjustStockPage(productId: p.id, adding: true)),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Restock'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 36,
                      child: OutlinedButton(
                        onPressed: () => _push(
                            context, MovementHistoryPage(productId: p.id)),
                        child: const Text('History'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
