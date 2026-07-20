import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/responsive.dart';

/// Shared page layout: a title/subtitle header over a scrollable, width-capped body.
class AdminPageScaffold extends StatelessWidget {
  const AdminPageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMobile = Responsive.isMobile(context);
    // Tighter gutters and a smaller header on phones; desktop is unchanged.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? AppSpacing.lg : AppSpacing.xl,
        isMobile ? AppSpacing.lg : AppSpacing.xl,
        isMobile ? AppSpacing.lg : AppSpacing.xl,
        // Room to scroll clear of the floating bottom navigation bar.
        isMobile ? 120 : AppSpacing.xl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: (isMobile
                          ? Theme.of(context).textTheme.headlineSmall
                          : Theme.of(context).textTheme.headlineMedium)
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              SizedBox(height: isMobile ? AppSpacing.lg : AppSpacing.xl),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// A responsive row of stat cards that wraps on narrow screens.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.cards});
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // On phones, up to three metrics still fit side by side (the cards
        // switch to a compact style themselves); more than that wraps to two.
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 480
                ? 2
                : (cards.isEmpty ? 1 : (cards.length <= 3 ? cards.length : 2));
        final spacing = constraints.maxWidth < 480 ? 8.0 : AppSpacing.md;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}
