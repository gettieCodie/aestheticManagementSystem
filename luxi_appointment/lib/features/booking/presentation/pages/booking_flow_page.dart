import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/content_shell.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../services/booking_data_service.dart';
import '../providers/booking_provider.dart';
import '../widgets/progress_header.dart';
import 'steps/book_appointment_step.dart';
import 'steps/client_info_step.dart';
import 'steps/review_booking_step.dart';
import 'steps/select_service_step.dart';

/// Hosts the four-step booking flow: progress header, animated step content and
/// the Previous / Next (Confirm) navigation footer.
class BookingFlowPage extends StatefulWidget {
  const BookingFlowPage({super.key});

  @override
  State<BookingFlowPage> createState() => _BookingFlowPageState();
}

class _BookingFlowPageState extends State<BookingFlowPage> {
  static const List<String> _stepLabels = [
    'Service',
    'Appointment',
    'Details',
    'Review',
  ];

  final GlobalKey<FormState> _clientFormKey = GlobalKey<FormState>();
  bool _submitting = false;

  /// Builds only the current step so off-screen steps never lay out or get
  /// hit-tested. State for each step lives in [BookingProvider].
  Widget _buildStep(int step) {
    switch (step) {
      case 0:
        return const SelectServiceStep();
      case 1:
        return const BookAppointmentStep();
      case 2:
        return ClientInfoStep(formKey: _clientFormKey);
      default:
        return const ReviewBookingStep();
    }
  }

  void _onBack(BookingProvider provider) {
    if (provider.isFirstStep) {
      Navigator.of(context).maybePop();
    } else {
      provider.previousStep();
    }
  }

  void _onNext(BookingProvider provider) {
    // Validate the form before leaving the client-info step.
    if (provider.currentStep == 2) {
      final valid = _clientFormKey.currentState?.validate() ?? false;
      if (!valid) return;
    }
    provider.nextStep();
  }

  Future<void> _confirm(BookingProvider provider) async {
    setState(() => _submitting = true);
    try {
      await provider.confirmBooking();
    } on SlotFullException catch (e) {
      // Someone else booked this exact slot while the client was filling in
      // Steps 3-4 — send them back to Appointment to pick a different time
      // instead of silently double-booking it.
      if (!mounted) return;
      setState(() => _submitting = false);
      provider.clearTime();
      provider.goToStep(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    } catch (e) {
      // Network error, server rejected it, backend not running, etc.
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not submit your booking. Please check your connection '
            'and try again.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    await _showSuccessDialog();
    if (!mounted) return;
    provider.reset();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _showSuccessDialog() {
    final scheme = Theme.of(context).colorScheme;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded,
                  size: 40, color: scheme.primary),
            ),
            const SizedBox(height: 18),
            Text(
              'Booking confirmed!',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Your appointment request has been received. We will be in '
              'touch shortly to confirm.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          // expand:false — dialog actions sit in an unbounded-width OverflowBar,
          // so the button must size to its content rather than fill.
          PrimaryButton(
            label: 'Done',
            expand: false,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();

    return PopScope(
      canPop: provider.isFirstStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) provider.previousStep();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => _onBack(provider),
          ),
          title: Text('Step ${provider.currentStep + 1} of ${provider.totalSteps}'),
        ),
        body: Column(
          children: [
            // Progress header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      maxWidth: AppSpacing.maxContentWidth),
                  child: ProgressHeader(
                    currentStep: provider.currentStep,
                    labels: _stepLabels,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            // Step content — only the active step is built.
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _ScrollableStep(
                  key: ValueKey<int>(provider.currentStep),
                  child: _buildStep(provider.currentStep),
                ),
              ),
            ),
            _FlowFooter(
              provider: provider,
              submitting: _submitting,
              onBack: () => _onBack(provider),
              onNext: () => _onNext(provider),
              onConfirm: () => _confirm(provider),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScrollableStep extends StatelessWidget {
  const _ScrollableStep({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ContentShell(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
        child: child,
      ),
    );
  }
}

/// Sticky footer with Previous and Next / Confirm actions.
class _FlowFooter extends StatelessWidget {
  const _FlowFooter({
    required this.provider,
    required this.submitting,
    required this.onBack,
    required this.onNext,
    required this.onConfirm,
  });

  final BookingProvider provider;
  final bool submitting;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLast = provider.isLastStep;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  if (!provider.isFirstStep) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: submitting ? null : onBack,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Previous'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    flex: provider.isFirstStep ? 1 : 1,
                    child: isLast
                        ? PrimaryButton(
                            label: 'Confirm Booking',
                            icon: Icons.check_circle_outline_rounded,
                            isLoading: submitting,
                            onPressed: onConfirm,
                          )
                        : PrimaryButton(
                            label: 'Continue',
                            icon: Icons.arrow_forward_rounded,
                            onPressed: provider.canContinue ? onNext : null,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
