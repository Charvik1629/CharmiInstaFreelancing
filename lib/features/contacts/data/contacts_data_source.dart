import 'package:flutter_contacts/flutter_contacts.dart';

import '../domain/device_contact.dart';

/// Reads and normalizes the device address book. Kept behind an interface so the
/// cubit/repository can be tested without the platform plugin.
abstract class ContactsDataSource {
  Future<List<DeviceContact>> readDeviceContacts();
}

class ContactsDataSourceImpl implements ContactsDataSource {
  const ContactsDataSourceImpl();

  @override
  Future<List<DeviceContact>> readDeviceContacts() async {
    final raw = await FlutterContacts.getAll(
      properties: {ContactProperty.phone, ContactProperty.email},
    );
    final out = <DeviceContact>[];
    for (final c in raw) {
      final phones = <String>{};
      for (final p in c.phones) {
        final n = ContactNormalizer.phone(p.number);
        if (n != null) phones.add(n);
      }
      final emails = <String>{};
      for (final e in c.emails) {
        final n = ContactNormalizer.email(e.address);
        if (n != null) emails.add(n);
      }
      final name = (c.displayName ?? '').trim();
      if (name.isEmpty && phones.isEmpty && emails.isEmpty) continue;
      out.add(DeviceContact(
        name: name.isEmpty ? (phones.isNotEmpty ? phones.first : emails.first) : name,
        phones: phones.toList(),
        emails: emails.toList(),
      ));
    }
    return out;
  }
}
