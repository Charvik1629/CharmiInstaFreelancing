part of 'contact_sync_cubit.dart';

enum SyncStatus { initial, permissionDenied, loading, loaded, error }

class ContactSyncState extends Equatable {
  const ContactSyncState({
    this.status = SyncStatus.initial,
    this.payload,
    this.uploading = false,
    this.message,
  });

  final SyncStatus status;
  final ContactSyncPayload? payload;
  final bool uploading;

  /// Transient snackbar text (upload result / read error).
  final String? message;

  int get count => payload?.count ?? 0;

  ContactSyncState copyWith({
    SyncStatus? status,
    ContactSyncPayload? payload,
    bool? uploading,
    String? message,
    bool clearMessage = false,
  }) {
    return ContactSyncState(
      status: status ?? this.status,
      payload: payload ?? this.payload,
      uploading: uploading ?? this.uploading,
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  List<Object?> get props => [status, payload, uploading, message];
}
