import '../../../core/error/failure.dart';
import '../../../core/network/base_repository.dart';
import '../../../core/utils/result.dart';
import '../data/contacts_data_source.dart';
import '../data/contacts_remote_data_source.dart';
import 'contact_match.dart';
import 'contact_sync_payload.dart';

/// Contact-sync domain contract: read the device address book, then check which
/// numbers belong to approved Nexveero users via `POST /contacts/sync`.
abstract class ContactsRepository {
  /// Reads device contacts and returns a normalized, de-duplicated payload.
  Future<Result<ContactSyncPayload>> buildPayload();

  /// Uploads [phones] (address-book numbers) and returns each one's match
  /// status (registered + the matched user when approved).
  Future<Result<List<ContactMatch>>> sync(List<String> phones);
}

class ContactsRepositoryImpl with BaseRepository implements ContactsRepository {
  ContactsRepositoryImpl(this._dataSource, this._remote);

  final ContactsDataSource _dataSource;
  final ContactsRemoteDataSource _remote;

  @override
  Future<Result<ContactSyncPayload>> buildPayload() async {
    try {
      final contacts = await _dataSource.readDeviceContacts();
      return Success(ContactSyncPayload.fromDevice(contacts));
    } catch (e) {
      return const Err(UnknownFailure('Could not read contacts'));
    }
  }

  @override
  Future<Result<List<ContactMatch>>> sync(List<String> phones) {
    if (phones.isEmpty) return Future.value(const Success(<ContactMatch>[]));
    // The API caps at 1000 numbers per call.
    final capped = phones.length > 1000 ? phones.sublist(0, 1000) : phones;
    return guard(() => _remote.sync(capped));
  }
}
