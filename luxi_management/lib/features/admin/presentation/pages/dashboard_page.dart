import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../billing/state/billing_store.dart';
import '../../../staff/state/staff_store.dart';
import '../../models/product.dart';
import '../../state/admin_store.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_card.dart';
import 'page_scaffold.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminStore>();
    final billing = context.watch<BillingStore>();
    final staff = context.watch<StaffStore>();
    final scheme = Theme.of(context).colorScheme;

    final lowStock = admin.products
        .where((p) => p.status != InventoryStatus.inStock)
        .toList();
    final recent = billing.invoices.take(5).toList();
    final firestoreErrors = [
      ...admin.firestoreErrors,
      ...billing.firestoreErrors,
      ...staff.firestoreErrors,
    ];

    return AdminPageScaffold(
      title: 'Dashboard',
      subtitle: 'Overview across all four branches',
      children: [
        FirestoreErrorBanner(errors: firestoreErrors),
        StatRow(cards: [
          StatCard(
            label: 'Revenue (billed)',
            value: Formatters.peso(billing.totalRevenue),
            icon: Icons.attach_money_rounded,
          ),
          StatCard(
            label: 'Outstanding',
            value: Formatters.peso(billing.outstanding),
            icon: Icons.error_outline_rounded,
            accent: const Color(0xFFE05252),
          ),
          StatCard(
            label: 'Services',
            value: '${admin.services.length}',
            icon: Icons.spa_rounded,
          ),
          StatCard(
            label: 'Products',
            value: '${admin.products.length}',
            icon: Icons.inventory_2_rounded,
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Needs Restock',
          icon: Icons.warning_amber_rounded,
          child: lowStock.isEmpty
              ? Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text('All products are well stocked.',
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                )
              : Column(
                  children: [
                    for (final p in lowStock)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(p.name)),
                            Text('${p.totalStock} ${p.unit}',
                                style: TextStyle(color: scheme.onSurfaceVariant)),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: p.status.color.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(p.status.label,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: p.status.color)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Recent Invoices',
          icon: Icons.receipt_long_rounded,
          child: Column(
            children: [
              for (final inv in recent)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(inv.customerName,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                                '${inv.id} · ${inv.items.isNotEmpty ? inv.items.first.name : ''}',
                                style: TextStyle(
                                    fontSize: 12, color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(Formatters.peso(inv.total),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(inv.status.label,
                              style: TextStyle(
                                  fontSize: 11, color: inv.status.color)),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
