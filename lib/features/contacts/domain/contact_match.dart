import '../../../core/extensions/json_extensions.dart';
import '../../../core/models/user.dart';

/// One entry of the `POST /contacts/sync` response: a submitted phone number and
/// whether it belongs to an approved Nexveero user (with that user when so).
class ContactMatch {
  const ContactMatch({
    required this.phone,
    required this.registered,
    this.user,
  });

  /// The number as submitted (echoed back by the server).
  final String phone;

  /// True when the number belongs to an approved user.
  final bool registered;

  /// The matched app user (only when [registered]).
  final User? user;

  factory ContactMatch.fromJson(Map<String, dynamic> json) => ContactMatch(
        phone: json.asStringOr('phone', ''),
        registered: json.asBool('registered'),
        user: json.asMap('user') != null
            ? User.fromJson(json.asMap('user')!)
            : null,
      );
}
