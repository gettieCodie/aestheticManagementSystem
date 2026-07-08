import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';

/// Compact selectable chip for a single time slot.
class TimeSlotCard extends StatelessWidget {
  const TimeSlotCard({
    super.key,
    required this.time,
    required this.selected,
    required this.onTap,
  });

  final TimeOfDay time;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: selected ? scheme.primary : scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              Formatters.time(time),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
