/// Reusable `TextFormField` validators.
///
/// Each returns `null` when valid and an error message otherwise, so they can
/// be passed straight to `validator:`. Composed with [all] when a field has
/// more than one rule.
abstract final class Validate {
  /// Runs validators in order and returns the first failure.
  static String? Function(String?) all(List<String? Function(String?)> rules) {
    return (value) {
      for (final rule in rules) {
        final error = rule(value);
        if (error != null) return error;
      }
      return null;
    };
  }

  static String? required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  /// Whole number ≥ 0. Empty passes — pair with [required] when mandatory.
  static String? Function(String?) number({
    int min = 0,
    int? max,
    String label = 'Value',
  }) {
    return (v) {
      if (v == null || v.trim().isEmpty) return null;
      final n = num.tryParse(v.trim());
      if (n == null) return 'Enter a number';
      if (n < min) return '$label cannot be less than $min';
      if (max != null && n > max) return '$label cannot exceed $max';
      return null;
    };
  }

  /// Philippine mobile/landline: 7–13 digits, optional +63 prefix.
  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) return 'Enter a valid contact number';
    if (digits.length > 13) return 'Contact number is too long';
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Enter a valid email address';
  }

  /// Guards against typos like a ₱1 package or a ₱9,999,999 serum.
  static String? Function(String?) money({
    double min = 0,
    double max = 1000000,
    String label = 'Amount',
  }) {
    return (v) {
      if (v == null || v.trim().isEmpty) return null;
      final n = double.tryParse(v.trim());
      if (n == null) return 'Enter an amount';
      if (n < min) return '$label cannot be less than $min';
      if (n > max) return '$label looks too large — check the value';
      return null;
    };
  }

  static String? Function(String?) minLength(int length) => (v) =>
      (v != null && v.trim().isNotEmpty && v.trim().length < length)
          ? 'Must be at least $length characters'
          : null;
}
