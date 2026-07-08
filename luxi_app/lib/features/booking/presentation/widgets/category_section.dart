import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/responsive.dart';
import '../../models/service_category.dart';
import '../../models/service_model.dart';
import 'service_card.dart';

/// A titled category header followed by its list/grid of [ServiceCard]s.
class CategorySection extends StatelessWidget {
  const CategorySection({
    super.key,
    required this.category,
    required this.selectedService,
    required this.onServiceSelected,
  });

  final ServiceCategory category;
  final ServiceModel? selectedService;
  final ValueChanged<ServiceModel> onServiceSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final int columns = Responsive.isMobile(context) ? 1 : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(category.icon, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              category.title,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _ServiceLayout(
          columns: columns,
          services: category.services,
          selectedService: selectedService,
          onServiceSelected: onServiceSelected,
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// Lays services out as a single column on mobile or a wrapping grid on larger
/// screens, keeping cards touch-friendly at every width.
class _ServiceLayout extends StatelessWidget {
  const _ServiceLayout({
    required this.columns,
    required this.services,
    required this.selectedService,
    required this.onServiceSelected,
  });

  final int columns;
  final List<ServiceModel> services;
  final ServiceModel? selectedService;
  final ValueChanged<ServiceModel> onServiceSelected;

  @override
  Widget build(BuildContext context) {
    if (columns == 1) {
      return Column(
        children: [
          for (final service in services)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ServiceCard(
                service: service,
                selected: service == selectedService,
                onTap: () => onServiceSelected(service),
              ),
            ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.md;
        final double itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final service in services)
              SizedBox(
                width: itemWidth,
                child: ServiceCard(
                  service: service,
                  selected: service == selectedService,
                  onTap: () => onServiceSelected(service),
                ),
              ),
          ],
        );
      },
    );
  }
}
