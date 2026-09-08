import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/contact_sync_payload.dart';
import '../../domain/contacts_repository.dart';

part 'contact_sync_state.dart';

/// Drives the Contact Sync screen. Permission is handled in the page (needs
/// UI); the cubit reads + normalizes contacts and attempts the (gated) upload.
class ContactSyncCubit extends Cubit<ContactSyncState> {
  ContactSyncCubit(this._repository) : super(const ContactSyncState());

  final ContactsRepository _repository;

  /// Reads the address book and builds the normalized payload.
  Future<void> load() async {
    emit(state.copyWith(status: SyncStatus.loading, clearMessage: true));
    final result = await _repository.buildPayload();
    switch (result) {
      case Success(value: final payload):
        emit(state.copyWith(status: SyncStatus.loaded, payload: payload));
      case Err(failure: final f):
        emit(state.copyWith(status: SyncStatus.error, message: f.message));
    }
  }

  /// Marks that the OS permission was denied so the page can prompt for Settings.
  void permissionDenied() =>
      emit(state.copyWith(status: SyncStatus.permissionDenied));

  /// Uploads the payload (gated until the endpoint exists).
  Future<void> sync() async {
    final payload = state.payload;
    if (payload == null || state.uploading) return;
    emit(state.copyWith(uploading: true, clearMessage: true));
    final result = await _repository.upload(payload);
    switch (result) {
      case Success():
        emit(state.copyWith(uploading: false, message: 'Contacts synced'));
      case Err(failure: final f):
        emit(state.copyWith(uploading: false, message: f.message));
    }
  }
}
