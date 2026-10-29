import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/contact_match.dart';

/// Uploads address-book numbers to `POST /contacts/sync` and returns, for each,
/// whether it belongs to an approved Nexveero user.
abstract class ContactsRemoteDataSource {
  Future<List<ContactMatch>> sync(List<String> phones);
}

class ContactsRemoteDataSourceImpl implements ContactsRemoteDataSource {
  ContactsRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<ContactMatch>> sync(List<String> phones) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.contactSync,
      // The API only needs the numbers (1–1000). It echoes each back with a
      // `registered` flag and the matched user when approved.
      data: {'phones': phones},
    );
    return ApiEnvelope.list(res.data, ContactMatch.fromJson).items;
  }
}
