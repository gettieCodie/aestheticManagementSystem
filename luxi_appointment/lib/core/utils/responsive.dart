import 'package:flutter/widgets.dart';

/// Simple breakpoint helper for mobile / tablet / desktop layouts.
enum DeviceType { mobile, tablet, desktop }

abstract final class Responsive {
  static const double tabletBreakpoint = 600;
  static const double desktopBreakpoint = 1024;

  static DeviceType of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= desktopBreakpoint) return DeviceType.desktop;
    if (width >= tabletBreakpoint) return DeviceType.tablet;
    return DeviceType.mobile;
  }

  static bool isMobile(BuildContext context) =>
      of(context) == DeviceType.mobile;

  static bool isDesktop(BuildContext context) =>
      of(context) == DeviceType.desktop;

  /// Number of columns for grid-style content across breakpoints.
  static int gridColumns(BuildContext context) {
    switch (of(context)) {
      case DeviceType.desktop:
        return 3;
      case DeviceType.tablet:
        return 2;
      case DeviceType.mobile:
        return 1;
    }
  }
}
