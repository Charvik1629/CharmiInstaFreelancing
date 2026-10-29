part of 'contact_sync_cubit.dart';

enum SyncStatus { initial, permissionDenied, loading, loaded, error }

/// One row in the Find-friends list: a device contact paired with its match
/// result. [user] is non-null (and [registered] true) when the number belongs
/// to an approved Nexveero user — otherwise the row offers an invite.
class ContactEntry extends Equatable {
  const ContactEntry({
    required this.name,
    required this.phone,
    this.user,
  });

  final String name;
  final String phone;
  final User? user;

  bool get registered => user != null;

  @override
  List<Object?> get props => [name, phone, user];
}

class ContactSyncState extends Equatable {
  const ContactSyncState({
    this.status = SyncStatus.initial,
    this.entries = const [],
    this.syncing = false,
    this.message,
  });

  final SyncStatus status;

  /// All device contacts with their match status, registered users first.
  final List<ContactEntry> entries;

  /// True while `POST /contacts/sync` is in flight.
  final bool syncing;

  /// Transient snackbar text (sync result / read error).
  final String? message;

  int get count => entries.length;
  int get registeredCount => entries.where((e) => e.registered).length;

  ContactSyncState copyWith({
    SyncStatus? status,
    List<ContactEntry>? entries,
    bool? syncing,
    String? message,
    bool clearMessage = false,
  }) {
    return ContactSyncState(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      syncing: syncing ?? this.syncing,
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  List<Object?> get props => [status, entries, syncing, message];
}
