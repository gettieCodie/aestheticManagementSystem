/// Reusable form-field validators for the client information step.
///
/// Each returns `null` when valid or an error message otherwise, matching the
/// signature expected by [TextFormField.validator].
abstract final class Validators {
  static final RegExp _email = RegExp(
    r'^[\w.+-]+@[\w-]+\.[\w.-]+$',
  );

  // Accepts +, spaces, dashes and parentheses; requires 7-15 digits.
  static final RegExp _phoneDigits = RegExp(r'\d');

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field is required';
    }
    return null;
  }

  static String? name(String? value) {
    final base = required(value, field: 'Full name');
    if (base != null) return base;
    if (value!.trim().length < 2) {
      return 'Please enter your full name';
    }
    return null;
  }

  static String? email(String? value) {
    final base = required(value, field: 'Email address');
    if (base != null) return base;
    if (!_email.hasMatch(value!.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? phone(String? value) {
    final base = required(value, field: 'Phone number');
    if (base != null) return base;
    final digits = _phoneDigits.allMatches(value!).length;
    if (digits < 7 || digits > 15) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? facebook(String? value) {
    return required(value, field: 'Facebook profile');
  }
}
