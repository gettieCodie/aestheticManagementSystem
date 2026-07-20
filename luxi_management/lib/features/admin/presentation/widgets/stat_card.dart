import 'package:flutter/material.dart';

/// Small metric card used across the dashboard, inventory and sales headers.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accent;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    // Cards shrink themselves when they're laid out narrow (phones, 3-up
    // rows) so a metric strip doesn't eat a whole screen of height.
    return LayoutBuilder(
      builder: (context, constraints) =>
          _card(context, compact: constraints.maxWidth < 150),
    );
  }

  Widget _card(BuildContext context, {required bool compact}) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.primary;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                height: compact ? 28 : 34,
                width: compact ? 28 : 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(compact ? 8 : 9),
                ),
                child: Icon(icon, size: compact ? 16 : 19, color: color),
              ),
              const Spacer(),
              if (trailing != null && !compact)
                Text(
                  trailing!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: compact
                ? const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)
                : Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: compact
                ? TextStyle(fontSize: 10.5, height: 1.2, color: scheme.onSurfaceVariant)
                : Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
          ),
        ],
      ),
    );
  }
}
