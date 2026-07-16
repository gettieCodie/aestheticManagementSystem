import 'package:flutter/material.dart';

/// Step progress indicator shown at the top of the booking flow.
///
/// Renders a numbered node per step with a connecting track that fills as the
/// user advances. Completed steps show a check; the active step is emphasised.
class ProgressHeader extends StatelessWidget {
  const ProgressHeader({
    super.key,
    required this.currentStep,
    required this.labels,
  });

  final int currentStep;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          _StepNode(
            index: i,
            label: labels[i],
            state: _stateFor(i),
          ),
          if (i < labels.length - 1)
            Expanded(
              child: _Connector(filled: i < currentStep),
            ),
        ],
      ],
    );
  }

  _StepState _stateFor(int i) {
    if (i < currentStep) return _StepState.done;
    if (i == currentStep) return _StepState.active;
    return _StepState.upcoming;
  }
}

enum _StepState { done, active, upcoming }

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.index,
    required this.label,
    required this.state,
  });

  final int index;
  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    late final Color bg;
    late final Color fg;
    switch (state) {
      case _StepState.done:
        bg = scheme.primary;
        fg = scheme.onPrimary;
      case _StepState.active:
        bg = scheme.primary;
        fg = scheme.onPrimary;
      case _StepState.upcoming:
        bg = scheme.surfaceContainerHighest;
        fg = scheme.onSurfaceVariant;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: state == _StepState.active
                ? Border.all(color: scheme.primary.withValues(alpha: 0.35), width: 4)
                : null,
          ),
          alignment: Alignment.center,
          child: state == _StepState.done
              ? Icon(Icons.check, size: 18, color: fg)
              : Text(
                  '${index + 1}',
                  style: TextStyle(color: fg, fontWeight: FontWeight.w700),
                ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 62,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 11,
              height: 1.1,
              fontWeight:
                  state == _StepState.active ? FontWeight.w700 : FontWeight.w500,
              color: state == _StepState.upcoming
                  ? scheme.onSurfaceVariant
                  : scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 3,
        color: filled ? scheme.primary : scheme.surfaceContainerHighest,
      ),
    );
  }
}
