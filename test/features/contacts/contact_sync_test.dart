import 'package:charmi_insta_freelancing/features/contacts/data/contacts_data_source.dart';
import 'package:charmi_insta_freelancing/features/contacts/domain/contact_sync_payload.dart';
import 'package:charmi_insta_freelancing/features/contacts/domain/contacts_repository.dart';
import 'package:charmi_insta_freelancing/features/contacts/domain/device_contact.dart';
import 'package:charmi_insta_freelancing/features/contacts/presentation/cubit/contact_sync_cubit.dart';
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
      final repo = ContactsRepositoryImpl(_FakeDataSource(const [
        DeviceContact(name: 'Bob', phones: ['+919876543210']),
        DeviceContact(name: 'Bob2', phones: ['9876543210']),
      ]));
      final result = await repo.buildPayload();
      expect(result.isSuccess, isTrue);
      expect((result as Success).value.count, 1);
    });

    test('buildPayload maps read errors to a failure', () async {
      final repo = ContactsRepositoryImpl(_ThrowingDataSource());
      final result = await repo.buildPayload();
      expect(result.isFailure, isTrue);
    });

    test('upload is gated (no endpoint yet)', () async {
      final repo = ContactsRepositoryImpl(_FakeDataSource(const []));
      final result = await repo.upload(const ContactSyncPayload(contacts: []));
      expect(result.isFailure, isTrue);
    });
  });

  group('ContactSyncCubit', () {
    test('load emits loaded with the payload', () async {
      final cubit = ContactSyncCubit(ContactsRepositoryImpl(_FakeDataSource(const [
        DeviceContact(name: 'Bob', phones: ['+919876543210']),
      ])));
      await cubit.load();
      expect(cubit.state.status, SyncStatus.loaded);
      expect(cubit.state.count, 1);
    });

    test('sync surfaces the gated message', () async {
      final cubit = ContactSyncCubit(ContactsRepositoryImpl(_FakeDataSource(const [
        DeviceContact(name: 'Bob', phones: ['+919876543210']),
      ])));
      await cubit.load();
      await cubit.sync();
      expect(cubit.state.uploading, isFalse);
      expect(cubit.state.message, isNotNull);
    });
  });
}
