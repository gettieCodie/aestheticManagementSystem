import 'package:flutter/material.dart';

/// Lightweight display formatters (no intl dependency required).
abstract final class Formatters {
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<String> _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  /// e.g. "Wed, 08 Jul 2026".
  static String date(DateTime d) {
    final weekday = _weekdays[d.weekday - 1];
    final day = d.day.toString().padLeft(2, '0');
    return '$weekday, $day ${_months[d.month - 1]} ${d.year}';
  }

  /// 12-hour clock, e.g. "9:00 AM".
  static String time(TimeOfDay t) {
    final period = t.hour >= 12 ? 'PM' : 'AM';
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  /// e.g. "₱1,800".
  static String peso(double amount) {
    final whole = amount.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
      buffer.write(whole[i]);
    }
    return '₱$buffer';
  }

  /// e.g. "60 min" or "1 hr 30 min".
  static String duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h hr' : '$h hr $m min';
  }
}
