import 'package:flutter/material.dart';

/// App-wide primary call-to-action button.
///
/// Wraps [FilledButton] with an optional leading icon and a busy state that
/// shows a spinner and blocks taps — handy once real async calls are wired in.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !isLoading;

    final Widget child = isLoading
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final button = FilledButton(
      onPressed: enabled ? onPressed : null,
      child: child,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
