import 'package:flutter/widgets.dart';

/// Breakpoint helpers for the admin layout.
abstract final class Responsive {
  static const double compact = 720; // below = mobile (drawer nav)
  static const double expanded = 1100; // above = wide tables

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expanded;
}
