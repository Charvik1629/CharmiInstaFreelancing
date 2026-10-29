import 'package:charmi_insta_freelancing/features/contacts/data/contacts_data_source.dart';
import 'package:charmi_insta_freelancing/features/contacts/data/contacts_remote_data_source.dart';
import 'package:charmi_insta_freelancing/features/contacts/domain/contact_match.dart';
import 'package:charmi_insta_freelancing/features/contacts/domain/contact_sync_payload.dart';
import 'package:charmi_insta_freelancing/features/contacts/domain/contacts_repository.dart';
import 'package:charmi_insta_freelancing/features/contacts/domain/device_contact.dart';
import 'package:charmi_insta_freelancing/features/contacts/presentation/cubit/contact_sync_cubit.dart';
import 'package:charmi_insta_freelancing/core/models/user.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDataSource implements ContactsDataSource {
  _FakeDataSource(this.contacts);
  final List<DeviceContact> contacts;
  @override
  Future<List<DeviceContact>> readDeviceContacts() async => contacts;
}

class _ThrowingDataSource implements ContactsDataSource {
  @override
  Future<List<DeviceContact>> readDeviceContacts() async => throw Exception('boom');
}

/// Returns a match (registered + user) for any phone in [registered], the rest
/// as unregistered — mirroring `POST /contacts/sync`.
class _FakeRemote implements ContactsRemoteDataSource {
  _FakeRemote(this.registered);
  final Map<String, User> registered;
  @override
  Future<List<ContactMatch>> sync(List<String> phones) async => [
        for (final p in phones)
          ContactMatch(
            phone: p,
            registered: registered.containsKey(p),
            user: registered[p],
          ),
      ];
}

User _user(int id, String name) => User(id: id, name: name);

void main() {
  group('ContactNormalizer.phone', () {
    test('keeps a leading + and strips separators', () {
      expect(ContactNormalizer.phone('+91 98765-43210'), '+919876543210');
      expect(ContactNormalizer.phone('(020) 7946 0958'), '02079460958');
    });
    test('rejects too-short strings', () {
      expect(ContactNormalizer.phone('123'), isNull);
      expect(ContactNormalizer.phone('n/a'), isNull);
    });
  });

  group('ContactNormalizer.phoneKey', () {
    test('collapses formats of the same number to last 10 digits', () {
      final a = ContactNormalizer.phoneKey('+91 98765 43210');
      final b = ContactNormalizer.phoneKey('098765 43210');
      final c = ContactNormalizer.phoneKey('9876543210');
      expect(a, '9876543210');
      expect(a, b);
      expect(a, c);
    });
  });

  group('ContactNormalizer.email', () {
    test('lowercases and validates', () {
      expect(ContactNormalizer.email('  Bob@Example.COM '), 'bob@example.com');
      expect(ContactNormalizer.email('not-an-email'), isNull);
    });
  });

  group('ContactSyncPayload.fromDevice', () {
    test('drops un-syncable contacts and de-duplicates by phone', () {
      final raw = [
        const DeviceContact(name: 'Bob', phones: ['+919876543210']),
        const DeviceContact(name: 'Bob (work)', phones: ['098765 43210']), // dup number
        const DeviceContact(name: 'No Contact Info'), // no phone/email -> dropped
        const DeviceContact(name: 'Carol', emails: ['carol@x.com']),
      ];
      final payload = ContactSyncPayload.fromDevice(raw);
      expect(payload.count, 2); // Bob (deduped) + Carol
      expect(payload.toJson()['contacts'], hasLength(2));
    });
  });

  group('ContactsRepository', () {
    test('buildPayload normalizes + dedupes from the data source', () async {
      final repo = ContactsRepositoryImpl(
        _FakeDataSource(const [
          DeviceContact(name: 'Bob', phones: ['+919876543210']),
          DeviceContact(name: 'Bob2', phones: ['9876543210']),
        ]),
        _FakeRemote(const {}),
      );
      final result = await repo.buildPayload();
      expect(result.isSuccess, isTrue);
      expect((result as Success).value.count, 1);
    });

    test('buildPayload maps read errors to a failure', () async {
      final repo = ContactsRepositoryImpl(_ThrowingDataSource(), _FakeRemote(const {}));
      final result = await repo.buildPayload();
      expect(result.isFailure, isTrue);
    });

    test('sync returns a match per phone', () async {
      final repo = ContactsRepositoryImpl(
        _FakeDataSource(const []),
        _FakeRemote({'+919876543210': _user(1, 'Bob')}),
      );
      final result = await repo.sync(['+919876543210', '+910000000000']);
      expect(result.isSuccess, isTrue);
      final matches = (result as Success).value;
      expect(matches, hasLength(2));
      expect(matches.firstWhere((m) => m.phone == '+919876543210').registered, isTrue);
      expect(matches.firstWhere((m) => m.phone == '+910000000000').registered, isFalse);
    });

    test('sync short-circuits an empty list without calling the API', () async {
      final repo = ContactsRepositoryImpl(_FakeDataSource(const []), _FakeRemote(const {}));
      final result = await repo.sync(const []);
      expect(result.isSuccess, isTrue);
      expect((result as Success).value, isEmpty);
    });
  });

  group('ContactSyncCubit', () {
    test('load reads contacts, syncs, and lists registered users first', () async {
      final cubit = ContactSyncCubit(ContactsRepositoryImpl(
        _FakeDataSource(const [
          DeviceContact(name: 'Zed', phones: ['+910000000000']), // not registered
          DeviceContact(name: 'Bob', phones: ['+919876543210']), // registered
        ]),
        _FakeRemote({'+919876543210': _user(1, 'Bob Nex')}),
      ));
      await cubit.load();
      expect(cubit.state.status, SyncStatus.loaded);
      expect(cubit.state.syncing, isFalse);
      expect(cubit.state.count, 2);
      expect(cubit.state.registeredCount, 1);
      // Registered contact sorts to the top and shows its Nexveero name.
      expect(cubit.state.entries.first.registered, isTrue);
      expect(cubit.state.entries.first.name, 'Bob Nex');
    });
  });
}
