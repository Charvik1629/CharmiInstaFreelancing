import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/permissions/app_permission.dart';
import '../../../../core/permissions/permission_flow.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../chat/domain/entities/conversation.dart';
import '../../../chat/domain/repositories/chat_repository.dart';
import '../cubit/contact_sync_cubit.dart';

/// Find friends / Contact sync (Module 8). Reads the device address book (behind
/// the permission flow), then checks every number against `POST /contacts/sync`:
/// contacts already on Nexveero open a chat, the rest get an Invite action.
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
      rationaleMessage:
          'Enable contacts access in Settings to find people you know.',
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
              return const LoadingView(message: 'Finding people you know…');
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
              return _Loaded(state: state);
          }
        },
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.state});
  final ContactSyncState state;

  @override
  Widget build(BuildContext context) {
    final entries = state.entries;
    if (entries.isEmpty) {
      return const EmptyView(
        title: 'No contacts to sync',
        subtitle: 'We didn’t find any contacts with a phone number.',
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
                Text('${state.registeredCount} on Nexveero',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${state.count} contacts synced · invite the rest',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, indent: 72, color: context.nexveero.border),
            itemBuilder: (context, i) => _ContactRow(entry: entries[i]),
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.entry});
  final ContactEntry entry;

  /// Opens (or reopens) a 1:1 chat with a contact already on Nexveero.
  Future<void> _message(BuildContext context) async {
    final user = entry.user!;
    final repo = sl<ChatRepository>();
    final result = await AppLoader.run(repo.startChat(user.id));
    if (!context.mounted) return;
    switch (result) {
      case Success(value: final Conversation conversation):
        context.push(AppRoutes.chatThread, extra: conversation);
      case Err(failure: final f):
        AppOverlays.snack(context, f.message);
    }
  }

  /// Invites a contact not yet on Nexveero (share sheet with the app link).
  Future<void> _invite() async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Join me on Nexveero — connect with buyers, sellers and '
            'businesses. https://nexveero.com',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final registered = entry.registered;
    final subtitle = registered
        ? (entry.user?.username != null ? '@${entry.user!.username}' : 'On Nexveero')
        : entry.phone;
    return ListTile(
      onTap: registered ? () => _message(context) : null,
      leading: AppAvatar(
        name: entry.name,
        imageUrl: registered ? MediaUrl.resolve(entry.user?.avatarUrl) : null,
        size: 44,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(entry.name,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (registered) ...[
            const SizedBox(width: 4),
            Icon(Icons.verified,
                size: 15, color: Theme.of(context).colorScheme.primary),
          ],
        ],
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: nex.textSecondary)),
      // Registered → tap row to message (no button). Unregistered → Invite.
      trailing: registered
          ? Icon(Icons.chat_bubble_outline, size: 20, color: nex.iconInactive)
          : OutlinedButton(
              onPressed: _invite,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: nex.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full)),
              ),
              child: const Text('Invite'),
            ),
    );
  }
}
