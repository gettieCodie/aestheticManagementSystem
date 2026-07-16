/// Lightweight display formatters (no intl dependency).
abstract final class Formatters {
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// e.g. "May 1, 2026"
  static String date(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  /// e.g. "₱17,500"
  static String peso(num amount) {
    final whole = amount.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
      buffer.write(whole[i]);
    }
    return '₱$buffer';
  }

  /// e.g. "60 min" or "1 hr 30 min"
  static String duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h hr' : '$h hr $m min';
  }
}
