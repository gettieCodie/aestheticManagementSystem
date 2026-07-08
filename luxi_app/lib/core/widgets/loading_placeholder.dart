import 'package:flutter/material.dart';

/// A soft shimmer-style placeholder block for loading states.
///
/// Uses a looping opacity animation (no external shimmer package needed) so it
/// can stand in for cards or list rows while mock/async data "loads".
class LoadingPlaceholder extends StatefulWidget {
  const LoadingPlaceholder({
    super.key,
    this.height = 80,
    this.width,
    this.borderRadius = 16,
  });

  final double height;
  final double? width;
  final double borderRadius;

  @override
  State<LoadingPlaceholder> createState() => _LoadingPlaceholderState();
}

class _LoadingPlaceholderState extends State<LoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 0.9).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        height: widget.height,
        width: widget.width ?? double.infinity,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

/// Convenience column of stacked [LoadingPlaceholder]s.
class LoadingList extends StatelessWidget {
  const LoadingList({super.key, this.itemCount = 4, this.itemHeight = 80});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: LoadingPlaceholder(height: itemHeight),
        ),
      ),
    );
  }
}
