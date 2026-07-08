import 'package:flutter/material.dart';

/// Holds the active [ThemeMode] and exposes a toggle.
///
/// Kept intentionally tiny — persistence (shared_preferences, etc.) can be
/// layered on later without touching the UI that consumes it.
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  void toggle() {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setMode(ThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }
}
