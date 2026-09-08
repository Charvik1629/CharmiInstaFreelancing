import '../extensions/string_extensions.dart';

/// Reusable, null-returning form validators (null = valid) for use with
/// TextFormField or manual checks. Centralized so rules stay consistent.
class Validators {
  Validators._();

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!v.isValidEmail) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value, {int min = 8}) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < min) return 'Password must be at least $min characters';
    return null;
  }

  static String? required(String? value, {String field = 'This field'}) {
    if (value.isNullOrBlank) return '$field is required';
    return null;
  }

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Name is required';
    if (v.length > 255) return 'Name is too long';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  /// Mobile number: 10–15 digits with an optional leading `+`.
  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Mobile number is required';
    if (!RegExp(r'^\+?\d{10,15}$').hasMatch(v)) {
      return 'Enter a valid mobile number';
    }
    return null;
  }

  /// GSTIN: 15 alphanumeric characters.
  static String? gst(String? value) {
    final v = value?.trim().toUpperCase() ?? '';
    if (v.isEmpty) return 'GST number is required';
    if (!RegExp(r'^[0-9A-Z]{15}$').hasMatch(v)) return 'GST must be 15 characters';
    return null;
  }

  /// PAN: 10 alphanumeric characters.
  static String? pan(String? value) {
    final v = value?.trim().toUpperCase() ?? '';
    if (v.isEmpty) return 'PAN is required';
    if (!RegExp(r'^[0-9A-Z]{10}$').hasMatch(v)) return 'PAN must be 10 characters';
    return null;
  }

  /// Aadhaar: 12 digits.
  static String? aadhaar(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Aadhaar is required';
    if (!RegExp(r'^\d{12}$').hasMatch(v)) return 'Aadhaar must be 12 digits';
    return null;
  }
}
