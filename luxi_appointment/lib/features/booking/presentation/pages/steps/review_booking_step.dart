import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/widgets/notice_banner.dart';
import '../../providers/booking_provider.dart';
import '../../widgets/booking_summary_card.dart';
import 'step_header.dart';

/// Step 4 — review every selection before confirming.
class ReviewBookingStep extends StatelessWidget {
  const ReviewBookingStep({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          title: 'Review booking',
          subtitle: 'Double-check your details before confirming.',
        ),
        const SizedBox(height: AppSpacing.xl),
        BookingSummaryCard(
          service: provider.selectedService,
          branch: provider.selectedBranch,
          date: provider.selectedDate,
          time: provider.selectedTime,
          client: provider.clientInfo,
        ),
        const SizedBox(height: AppSpacing.md),
        // Reiterate the pricing disclaimer next to the final price.
        const NoticeBanner(message: AppConstants.priceDisclaimer),
        const SizedBox(height: AppSpacing.md),
        const NoticeBanner(
          message: 'You will receive a confirmation once your appointment is '
              'reviewed by our team.',
          icon: Icons.mark_email_read_outlined,
        ),
      ],
    );
  }
}
