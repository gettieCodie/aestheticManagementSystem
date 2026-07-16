import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../models/service_config.dart';
import '../../state/admin_store.dart';
import '../widgets/section_card.dart';
import 'page_scaffold.dart';

/// POS Configuration — manage services & pricing, promo discount, payment methods.
class PosConfigPage extends StatelessWidget {
  const PosConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();

    return AdminPageScaffold(
      title: 'POS Configuration',
      subtitle: 'Manage services, pricing, and payment settings',
      children: [
        SectionCard(
          title: 'Services & Pricing',
          icon: Icons.attach_money_rounded,
          action: FilledButton.icon(
            onPressed: () => _openServiceDialog(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Service'),
          ),
          child: Column(
            children: [
              for (final service in store.services)
                _ServiceTile(service: service),
              if (store.services.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No services yet. Add your first one.'),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Promotional Discounts',
          icon: Icons.percent_rounded,
          child: _PromoDiscount(),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Payment Methods',
          icon: Icons.credit_card_rounded,
          child: Column(
            children: [
              for (final entry in store.paymentMethods.entries)
                SwitchListTile(
                  value: entry.value,
                  onChanged: (v) =>
                      context.read<AdminStore>().togglePaymentMethod(entry.key, v),
                  title: Text(entry.key),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configuration saved (mock).')),
              );
            },
            child: const Text('Save Configuration & Sync to All Branches'),
          ),
        ),
      ],
    );
  }

  Future<void> _openServiceDialog(BuildContext context, [ServiceConfig? existing]) {
    return showDialog<void>(
      context: context,
      builder: (_) => _ServiceDialog(existing: existing),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service});
  final ServiceConfig service;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  children: [
                    _meta(context, Formatters.duration(service.durationMinutes)),
                    _meta(context, Formatters.peso(service.price),
                        color: scheme.primary),
                    if (service.consumables.isNotEmpty)
                      _meta(context, '${service.consumables.length} consumable(s)'),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _ServiceDialog(existing: service),
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(Icons.delete_outline, size: 18, color: scheme.error),
            onPressed: () =>
                context.read<AdminStore>().deleteService(service.id),
          ),
        ],
      ),
    );
  }

  Widget _meta(BuildContext context, String text, {Color? color}) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: color != null ? FontWeight.w700 : FontWeight.w500,
          ),
    );
  }
}

class _PromoDiscount extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final rate = store.promoDiscountRate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Promo Discount Rate:'),
            const SizedBox(width: 12),
            SizedBox(
              width: 90,
              child: TextFormField(
                initialValue: rate.toStringAsFixed(0),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) => context
                    .read<AdminStore>()
                    .setPromoDiscountRate(double.tryParse(v) ?? 0),
              ),
            ),
            const SizedBox(width: 8),
            const Text('%'),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Example: ₱1,200 service with ${rate.toStringAsFixed(0)}% discount = '
            '${Formatters.peso(1200 * (1 - rate / 100))}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// Add/edit service dialog — this is how you input services during trials.
class _ServiceDialog extends StatefulWidget {
  const _ServiceDialog({this.existing});
  final ServiceConfig? existing;

  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _duration = TextEditingController(
      text: widget.existing?.durationMinutes.toString() ?? '');
  late final TextEditingController _price = TextEditingController(
      text: widget.existing?.price.toStringAsFixed(0) ?? '');
  late final TextEditingController _consumables = TextEditingController(
      text: widget.existing?.consumables.join(', ') ?? '');

  @override
  void dispose() {
    _name.dispose();
    _duration.dispose();
    _price.dispose();
    _consumables.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final store = context.read<AdminStore>();
    final consumables = _consumables.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final service = ServiceConfig(
      id: widget.existing?.id ?? store.newServiceId(),
      name: _name.text.trim(),
      durationMinutes: int.parse(_duration.text),
      price: double.parse(_price.text),
      consumables: consumables,
    );
    if (widget.existing == null) {
      store.addService(service);
    } else {
      store.updateService(service);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(isEdit ? 'Edit Service' : 'Add Service'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Service name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _duration,
                      decoration: const InputDecoration(labelText: 'Duration (min)'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) =>
                          (int.tryParse(v ?? '') == null) ? 'Number' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      decoration: const InputDecoration(labelText: 'Price (₱)'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) =>
                          (double.tryParse(v ?? '') == null) ? 'Number' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _consumables,
                decoration: const InputDecoration(
                  labelText: 'Consumables (comma-separated)',
                  hintText: 'Vitamin C Serum, Retinol Night Cream',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: Text(isEdit ? 'Save' : 'Add')),
      ],
    );
  }
}
