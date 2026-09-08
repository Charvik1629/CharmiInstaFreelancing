import '../../../core/error/failure.dart';
import '../../../core/utils/result.dart';
import '../data/contacts_data_source.dart';
import 'contact_sync_payload.dart';

/// Contact-sync domain contract. Reading + payload building work today; the
/// upload is stubbed because `/contacts/sync` does not exist yet (see
/// MISSING_APIS / ApiEndpoints.contactSync placeholder).
abstract class ContactsRepository {
  /// Reads device contacts and returns a normalized, de-duplicated payload.
  Future<Result<ContactSyncPayload>> buildPayload();

  /// Uploads the payload once the endpoint exists. Until then it returns a
  /// [ConfigFailure] so the UI can show "coming soon" without faking success.
  Future<Result<void>> upload(ContactSyncPayload payload);
}

class ContactsRepositoryImpl implements ContactsRepository {
  ContactsRepositoryImpl(this._dataSource);

  final ContactsDataSource _dataSource;

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
  Future<Result<void>> upload(ContactSyncPayload payload) async {
    // No backend endpoint yet — payload is built and ready to POST the moment
    // `/contacts/sync` lands. Wiring is a one-liner then.
    return const Err(
      ConfigFailure('Contact sync needs a backend endpoint (see MISSING_APIS).'),
    );
  }
}
