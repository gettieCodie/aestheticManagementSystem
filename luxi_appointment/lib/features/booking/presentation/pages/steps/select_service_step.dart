import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/widgets/loading_placeholder.dart';
import '../../../../../core/widgets/notice_banner.dart';
import '../../../models/service_category.dart';
import '../../../services/booking_data_service.dart';
import '../../providers/booking_provider.dart';
import '../../widgets/category_section.dart';
import 'step_header.dart';

/// Step 1 — browse services grouped by category and pick exactly one.
class SelectServiceStep extends StatefulWidget {
  const SelectServiceStep({super.key});

  @override
  State<SelectServiceStep> createState() => _SelectServiceStepState();
}

class _SelectServiceStepState extends State<SelectServiceStep> {
  final BookingDataService _data = const BookingDataService();
  late final Future<List<ServiceCategory>> _future =
      _data.fetchServiceCategories();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          title: 'Select a service',
          subtitle: 'Choose the treatment you would like to book.',
        ),
        const SizedBox(height: AppSpacing.lg),
        const NoticeBanner(message: AppConstants.priceDisclaimer),
        const SizedBox(height: AppSpacing.lg),
        FutureBuilder<List<ServiceCategory>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LoadingList(itemCount: 4, itemHeight: 92);
            }
            final categories = snapshot.data ?? const [];
            final provider = context.watch<BookingProvider>();

            return Column(
              children: [
                for (final category in categories)
                  CategorySection(
                    category: category,
                    selectedService: provider.selectedService,
                    onServiceSelected:
                        context.read<BookingProvider>().selectService,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
