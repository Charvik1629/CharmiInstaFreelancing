import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/permissions/app_permission.dart';
import '../../../../core/permissions/permission_flow.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/device_contact.dart';
import '../cubit/contact_sync_cubit.dart';

/// Contact Sync (Module 8, design "Find your people"). Reads the device address
/// book (behind the Module-7 permission flow), normalizes + de-duplicates it,
/// and builds the sync payload. Upload is gated — `/contacts/sync` isn't live.
class ContactSyncPage extends StatelessWidget {
  const ContactSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ContactSyncCubit>(),
      child: const _ContactSyncView(),
    );
  }
}

class _ContactSyncView extends StatefulWidget {
  const _ContactSyncView();

  @override
  State<_ContactSyncView> createState() => _ContactSyncViewState();
}

class _ContactSyncViewState extends State<_ContactSyncView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestAndLoad());
  }

  Future<void> _requestAndLoad() async {
    final cubit = context.read<ContactSyncCubit>();
    final outcome = await PermissionFlow.ensure(
      context,
      AppPermission.contacts,
      rationaleTitle: 'Contacts access needed',
      rationaleMessage: 'Enable contacts access in Settings to find people you know.',
    );
    if (!mounted) return;
    if (outcome.isUsable) {
      cubit.load();
    } else {
      cubit.permissionDenied();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find friends')),
      body: BlocConsumer<ContactSyncCubit, ContactSyncState>(
        listenWhen: (p, c) => p.message != c.message && c.message != null,
        listener: (context, state) => AppOverlays.snack(context, state.message!),
        builder: (context, state) {
          switch (state.status) {
            case SyncStatus.initial:
            case SyncStatus.loading:
              return const LoadingView(message: 'Reading your contacts…');
            case SyncStatus.permissionDenied:
              return EmptyView(
                title: 'Contacts access off',
                subtitle: 'Allow access to find people you know on Nexveero.',
                icon: Icons.contacts_outlined,
                actionLabel: 'Grant access',
                onAction: _requestAndLoad,
              );
            case SyncStatus.error:
              return ErrorView(
                message: state.message ?? 'Could not read contacts',
                onRetry: _requestAndLoad,
              );
            case SyncStatus.loaded:
              return _Loaded(payload: state);
          }
        },
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.payload});
  final ContactSyncState payload;

  @override
  Widget build(BuildContext context) {
    final contacts = payload.payload!.contacts;
    if (contacts.isEmpty) {
      return const EmptyView(
        title: 'No contacts to sync',
        subtitle: 'We didn’t find any contacts with a phone or email.',
        icon: Icons.contacts_outlined,
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: context.nexveero.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${contacts.length} contacts ready',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                const Text('Normalized and de-duplicated on your device.',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: contacts.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, indent: 72, color: context.nexveero.border),
            itemBuilder: (context, i) => _ContactRow(contact: contacts[i]),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: BlocBuilder<ContactSyncCubit, ContactSyncState>(
              buildWhen: (p, c) => p.uploading != c.uploading,
              builder: (context, state) => AppButton(
                label: 'Sync contacts',
                isLoading: state.uploading,
                onPressed: () => context.read<ContactSyncCubit>().sync(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact});
  final DeviceContact contact;

  @override
  Widget build(BuildContext context) {
    final detail = contact.phones.isNotEmpty
        ? contact.phones.first
        : (contact.emails.isNotEmpty ? contact.emails.first : '');
    return ListTile(
      leading: AppAvatar(name: contact.name, size: 44),
      title: Text(contact.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: detail.isEmpty
          ? null
          : Text(detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.nexveero.textSecondary)),
    );
  }
}
