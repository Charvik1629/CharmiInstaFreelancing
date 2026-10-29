import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/user.dart';
import '../../../../core/utils/result.dart';
import '../../domain/contact_match.dart';
import '../../domain/device_contact.dart';
import '../../domain/contacts_repository.dart';

part 'contact_sync_state.dart';

/// Drives the Find-friends (contact sync) screen: reads + normalizes the device
/// address book, then checks which numbers are approved Nexveero users via
/// `POST /contacts/sync` so the UI can offer "Message" (registered) or "Invite".
class ContactSyncCubit extends Cubit<ContactSyncState> {
  ContactSyncCubit(this._repository) : super(const ContactSyncState());

  final ContactsRepository _repository;

  /// Reads the address book and immediately syncs it so each contact shows its
  /// match status without a separate tap.
  Future<void> load() async {
    emit(state.copyWith(status: SyncStatus.loading, clearMessage: true));
    final result = await _repository.buildPayload();
    switch (result) {
      case Success(value: final payload):
        await _sync(payload.contacts);
      case Err(failure: final f):
        emit(state.copyWith(status: SyncStatus.error, message: f.message));
    }
  }

  /// Marks that the OS permission was denied so the page can prompt for Settings.
  void permissionDenied() =>
      emit(state.copyWith(status: SyncStatus.permissionDenied));

  Future<void> _sync(List<DeviceContact> contacts) async {
    emit(state.copyWith(syncing: true));
    // All unique numbers across the address book.
    final phones = <String>{for (final c in contacts) ...c.phones}.toList();
    final result = await _repository.sync(phones);

    switch (result) {
      case Success(value: final matches):
        emit(state.copyWith(
          status: SyncStatus.loaded,
          entries: _buildEntries(contacts, matches),
          syncing: false,
        ));
      case Err(failure: final f):
        // Sync failed: still show contacts (all as "invite") so the screen works.
        emit(state.copyWith(
          status: SyncStatus.loaded,
          entries: _buildEntries(contacts, const []),
          syncing: false,
          message: f.message,
        ));
    }
  }

  /// Pairs each device contact with its match (registered users first). A
  /// contact is "on Nexveero" when any of its numbers matched an approved user.
  List<ContactEntry> _buildEntries(
      List<DeviceContact> contacts, List<ContactMatch> matches) {
    final byPhone = <String, ContactMatch>{
      for (final m in matches)
        if (m.registered && m.user != null) m.phone: m,
    };
    final entries = <ContactEntry>[];
    for (final c in contacts) {
      User? matchedUser;
      for (final p in c.phones) {
        final m = byPhone[p];
        if (m != null) {
          matchedUser = m.user;
          break;
        }
      }
      final phone = c.phones.isNotEmpty
          ? c.phones.first
          : (c.emails.isNotEmpty ? c.emails.first : '');
      entries.add(ContactEntry(
        name: matchedUser?.name ?? c.name,
        phone: phone,
        user: matchedUser,
      ));
    }
    // Registered first, then by name.
    entries.sort((a, b) {
      if (a.registered != b.registered) return a.registered ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }
}
