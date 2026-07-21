/// Lightweight display formatters (no intl dependency).
abstract final class Formatters {
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// e.g. "May 1, 2026"
  static String date(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  /// e.g. "2:14 PM"
  static String time(DateTime d) {
    final period = d.hour < 12 ? 'AM' : 'PM';
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$hour:${d.minute.toString().padLeft(2, '0')} $period';
  }

  /// Rounds to the nearest centavo — guards against floating-point division
  /// (e.g. splitting a package price across sessions) leaving a sub-centavo
  /// residue that displays as ₱0 but is technically still `> 0`, which would
  /// otherwise leave a fully-paid invoice permanently "open."
  static double roundMoney(double amount) => (amount * 100).round() / 100;

  /// e.g. "₱17,500", or "−₱500" for negatives.
  static String peso(num amount) {
    final rounded = amount.round();
    // Group the digits only — feeding a leading "-" into the loop below
    // miscounts the thousands boundary (−500 came out as "₱-,500").
    final whole = rounded.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
      buffer.write(whole[i]);
    }
    return '${rounded < 0 ? '−' : ''}₱$buffer';
  }

  /// e.g. "60 min" or "1 hr 30 min"
  static String duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h hr' : '$h hr $m min';
  }
}
