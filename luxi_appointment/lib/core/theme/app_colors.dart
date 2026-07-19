import 'package:flutter/material.dart';

/// Central palette for the Luxi appointment app.
///
/// A clean medical/clinic aesthetic built around a professional blue/green
/// palette. These raw colors seed the [ColorScheme]s in `app_theme.dart` and
/// are also used directly for a few bespoke UI accents.
abstract final class AppColors {
  // Brand — premium antique gold.
  static const Color primary = Color(0xFFC5A037); // warm metallic gold
  static const Color primaryDark = Color(0xFFA5832A);
  static const Color secondary = Color(0xFFB68A2E); // deeper bronze-gold
  static const Color secondaryDark = Color(0xFF8F6E22);

  // Neutrals (light)
  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F2F5);

  // Neutrals (dark)
  static const Color darkBackground = Color(0xFF14120C);
  static const Color darkSurface = Color(0xFF1E1B14);
  static const Color darkSurfaceVariant = Color(0xFF2A251A);

  // Feedback
  static const Color success = Color(0xFF3E9E6E);
  static const Color error = Color(0xFFE05252);

  // Text
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);

  // Gradient used on the landing hero / logo.
  static const List<Color> heroGradient = [
    Color(0xFFD4B45A),
    Color(0xFFB8912F),
  ];
}
