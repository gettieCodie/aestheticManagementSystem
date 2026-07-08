import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../routes/app_routes.dart';
import '../providers/booking_provider.dart';

/// Modern landing page: clinic logo, welcome heading, short description and a
/// large "Book an Appointment" call to action.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  void _startBooking(BuildContext context) {
    // Fresh flow each time the user lands here and starts over.
    context.read<BookingProvider>().reset();
    Navigator.of(context).pushNamed(AppRoutes.booking);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: _ThemeToggle(),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 520 : 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const _LogoPlaceholder(),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        AppConstants.clinicName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              letterSpacing: 1.4,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        AppConstants.landingHeading,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        AppConstants.landingDescription,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      PrimaryButton(
                        label: 'Book an Appointment',
                        icon: Icons.calendar_month_rounded,
                        onPressed: () => _startBooking(context),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        AppConstants.tagline,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      width: 104,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(Icons.spa_rounded, color: Colors.white, size: 52),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    return IconButton(
      tooltip: controller.isDark ? 'Light mode' : 'Dark mode',
      onPressed: controller.toggle,
      icon: Icon(
        controller.isDark
            ? Icons.light_mode_rounded
            : Icons.dark_mode_rounded,
      ),
    );
  }
}
