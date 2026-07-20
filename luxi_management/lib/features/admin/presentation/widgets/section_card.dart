import 'package:flutter/material.dart';

/// A titled white card container used to group content on the admin pages.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.action,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A Material rather than a decorated Container: ListTile-family widgets
    // (SwitchListTile, CheckboxListTile) paint their background and ink onto
    // the nearest Material ancestor, and a DecoratedBox in between hides them.
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    // The action keeps its natural width, so the title is what
                    // gives way on a narrow screen.
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
