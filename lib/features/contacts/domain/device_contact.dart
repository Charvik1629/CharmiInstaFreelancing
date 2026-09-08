import 'package:equatable/equatable.dart';

/// Phone/email normalization helpers for contact sync. Kept pure so they are
/// unit-testable without the platform contacts plugin.
class ContactNormalizer {
  ContactNormalizer._();

  /// Normalizes a raw phone string to `+<digits>` (keeps a leading `+`, drops
  /// spaces, dashes, brackets, etc.). Returns null for anything without enough
  /// digits to be a real number.
  static String? phone(String raw) {
    final trimmed = raw.trim();
    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) return null; // too short to be a phone number
    return hasPlus ? '+$digits' : digits;
  }

  /// A dedupe key for a phone: the last 10 digits (so `+91 98765 43210`,
  /// `9876543210` and `098765 43210` collapse to one contact).
  static String? phoneKey(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) return null;
    return digits.length <= 10 ? digits : digits.substring(digits.length - 10);
  }

  static String? email(String raw) {
    final e = raw.trim().toLowerCase();
    return e.contains('@') && e.length >= 3 ? e : null;
  }
}

/// A single device contact, already normalized and de-duplicated.
class DeviceContact extends Equatable {
  const DeviceContact({
    required this.name,
    this.phones = const [],
    this.emails = const [],
  });

  final String name;
  final List<String> phones;
  final List<String> emails;

  /// Contacts with no phone and no email can't be matched server-side.
  bool get isSyncable => phones.isNotEmpty || emails.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (phones.isNotEmpty) 'phones': phones,
        if (emails.isNotEmpty) 'emails': emails,
      };

  @override
  List<Object?> get props => [name, phones, emails];
}
