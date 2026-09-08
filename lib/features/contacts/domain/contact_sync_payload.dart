import 'device_contact.dart';

/// The JSON body the app would POST to a (future) `/contacts/sync` endpoint.
/// Built entirely on-device; independent of the API, which does not exist yet.
class ContactSyncPayload {
  const ContactSyncPayload({required this.contacts});

  final List<DeviceContact> contacts;

  int get count => contacts.length;

  /// Builds a de-duplicated, normalized payload from raw device contacts.
  /// Contacts are keyed by their first matchable phone (falling back to email),
  /// so the same person listed twice collapses into one entry.
  factory ContactSyncPayload.fromDevice(List<DeviceContact> raw) {
    final byKey = <String, DeviceContact>{};
    for (final c in raw) {
      if (!c.isSyncable) continue;
      final key = c.phones.isNotEmpty
          ? (ContactNormalizer.phoneKey(c.phones.first) ?? c.name)
          : c.emails.first;
      byKey.putIfAbsent(key, () => c);
    }
    return ContactSyncPayload(contacts: byKey.values.toList());
  }

  Map<String, dynamic> toJson() => {
        'contacts': contacts.map((c) => c.toJson()).toList(),
      };
}
