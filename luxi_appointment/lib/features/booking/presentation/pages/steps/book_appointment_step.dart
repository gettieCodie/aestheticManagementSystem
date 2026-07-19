import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/responsive.dart';
import '../../../../../core/widgets/loading_placeholder.dart';
import '../../../../../core/widgets/notice_banner.dart';
import '../../../models/branch_model.dart';
import '../../../services/booking_data_service.dart';
import '../../providers/booking_provider.dart';
import '../../widgets/branch_card.dart';
import '../../widgets/time_slot_card.dart';
import 'step_header.dart';

/// Step 2 — pick a branch, a date, and a time slot.
class BookAppointmentStep extends StatefulWidget {
  const BookAppointmentStep({super.key});

  @override
  State<BookAppointmentStep> createState() => _BookAppointmentStepState();
}

class _BookAppointmentStepState extends State<BookAppointmentStep> {
  final BookingDataService _data = BookingDataService();
  late final Future<List<BranchModel>> _branches = _data.fetchBranches();

  String? _slotsCacheKey;
  Future<List<TimeOfDay>>? _slotsFuture;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Re-fetches available slots only when the branch or date actually
  /// changes — avoids re-querying Firestore on every unrelated rebuild
  /// (e.g. when the user later picks a time slot).
  Future<List<TimeOfDay>> _slotsFor(BranchModel? branch, DateTime? date) {
    final key = '${branch?.id}_${date?.toIso8601String()}';
    if (_slotsCacheKey != key) {
      _slotsCacheKey = key;
      _slotsFuture = _data.fetchTimeSlots(branchId: branch?.id, date: date);
    }
    return _slotsFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();
    final slots = _slotsFor(provider.selectedBranch, provider.selectedDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          title: 'Book appointment',
          subtitle: 'Pick a branch, date and time that suit you.',
        ),
        const SizedBox(height: AppSpacing.xl),
        const _SubTitle(icon: Icons.store_mall_directory_rounded, label: 'Branch'),
        const SizedBox(height: AppSpacing.md),
        _BranchSelector(future: _branches),
        const SizedBox(height: AppSpacing.xl),
        const _SubTitle(icon: Icons.calendar_today_rounded, label: 'Date'),
        const SizedBox(height: AppSpacing.md),
        _CalendarCard(firstDate: _today),
        const SizedBox(height: AppSpacing.xl),
        const _SubTitle(icon: Icons.access_time_rounded, label: 'Time'),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Clinic hours: 9:00 AM – 4:00 PM',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        _TimeSlotSelector(future: slots),
      ],
    );
  }
}

class _SubTitle extends StatelessWidget {
  const _SubTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _BranchSelector extends StatelessWidget {
  const _BranchSelector({required this.future});

  final Future<List<BranchModel>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BranchModel>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingList(itemCount: 2, itemHeight: 72);
        }
        if (snapshot.hasError) {
          return NoticeBanner(
            icon: Icons.error_outline_rounded,
            message: 'Could not load branches: ${snapshot.error}',
          );
        }
        final branches = snapshot.data ?? const [];
        if (branches.isEmpty) {
          return const NoticeBanner(
            icon: Icons.error_outline_rounded,
            message: 'No branches are available right now.',
          );
        }
        final selected = context.watch<BookingProvider>().selectedBranch;
        final columns = Responsive.isMobile(context) ? 1 : 2;

        return LayoutBuilder(
          builder: (context, constraints) {
            const spacing = AppSpacing.md;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final branch in branches)
                  SizedBox(
                    width: columns == 1 ? constraints.maxWidth : width,
                    child: BranchCard(
                      branch: branch,
                      selected: branch == selected,
                      onTap: () =>
                          context.read<BookingProvider>().selectBranch(branch),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.firstDate});

  final DateTime firstDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Read once — CalendarDatePicker manages its own selection highlight, so we
    // avoid rebuilding it on every date tap.
    final provider = context.read<BookingProvider>();

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      // CalendarDatePicker needs a bounded height; without it the day grid
      // collapses to zero size inside a scroll view.
      child: SizedBox(
        height: 340,
        child: CalendarDatePicker(
          initialDate: provider.selectedDate ?? firstDate,
          firstDate: firstDate,
          lastDate: firstDate.add(const Duration(days: 120)),
          onDateChanged: provider.selectDate,
        ),
      ),
    );
  }
}

class _TimeSlotSelector extends StatelessWidget {
  const _TimeSlotSelector({required this.future});

  final Future<List<TimeOfDay>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TimeOfDay>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingPlaceholder(height: 120);
        }
        final slots = snapshot.data ?? const [];
        final selected = context.watch<BookingProvider>().selectedTime;

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final slot in slots)
              TimeSlotCard(
                time: slot,
                selected: slot == selected,
                onTap: () =>
                    context.read<BookingProvider>().selectTime(slot),
              ),
          ],
        );
      },
    );
  }
}
