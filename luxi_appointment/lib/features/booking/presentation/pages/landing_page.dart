import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../dev/firestore_seeder.dart';
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (kDebugMode) const _SeedDemoDataButton(),
                    _ThemeToggle(),
                  ],
                ),
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

/// Debug-only button that writes the bundled dummy dataset into Firestore.
/// Never shown in release builds — see the `kDebugMode` guard above.
class _SeedDemoDataButton extends StatefulWidget {
  const _SeedDemoDataButton();

  @override
  State<_SeedDemoDataButton> createState() => _SeedDemoDataButtonState();
}

class _SeedDemoDataButtonState extends State<_SeedDemoDataButton> {
  bool _seeding = false;

  Future<void> _seed() async {
    setState(() => _seeding = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final summary = await FirestoreSeeder().seed();
      final total = summary.values.fold<int>(0, (a, b) => a + b);
      messenger.showSnackBar(
        SnackBar(content: Text('Seeded $total documents across ${summary.length} collections.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Seeding failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Seed demo data (dev only)',
      onPressed: _seeding ? null : _seed,
      icon: _seeding
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.cloud_upload_outlined),
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
