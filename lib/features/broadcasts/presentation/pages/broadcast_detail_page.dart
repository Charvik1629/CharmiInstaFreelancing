import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/broadcast_detail.dart';
import '../../domain/broadcasts_repository.dart';

/// Broadcast details (design "Broadcast info"): name, recipient count and the
/// full recipient list, with rename (PUT /broadcasts/{id}) and delete
/// (DELETE /broadcasts/{id}) from the overflow menu.
class BroadcastDetailPage extends StatefulWidget {
  const BroadcastDetailPage({super.key, required this.broadcastId, this.initialName});

  final int broadcastId;
  final String? initialName;

  @override
  State<BroadcastDetailPage> createState() => _BroadcastDetailPageState();
}

class _BroadcastDetailPageState extends State<BroadcastDetailPage> {
  final _repo = sl<BroadcastsRepository>();
  late Future<Result<BroadcastDetail>> _future = _repo.getDetail(widget.broadcastId);
  String? _name;

  void _reload() =>
      setState(() => _future = _repo.getDetail(widget.broadcastId));

  Future<void> _rename() async {
    final newName = await AppOverlays.prompt(
      context,
      title: 'Rename list',
      hint: 'List name',
      initialValue: _name ?? widget.initialName,
      confirmLabel: 'Save',
    );
    if (newName == null || newName.isEmpty || !mounted) return;
    final result = await _repo.update(widget.broadcastId, name: newName);
    if (!mounted) return;
    if (result.isSuccess) {
      _reload();
    } else {
      AppOverlays.snack(context, result.failureOrNull?.message ?? 'Could not rename');
    }
  }

  Future<void> _delete() async {
    final ok = await AppOverlays.confirm(
      context,
      title: 'Delete broadcast list?',
      message: 'This removes the list and its recipients. Messages already sent stay.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final result = await _repo.delete(widget.broadcastId);
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.of(context).pop(true);
    } else {
      AppOverlays.snack(context, result.failureOrNull?.message ?? 'Could not delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Broadcast info'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'rename' ? _rename() : _delete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete list')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<Result<BroadcastDetail>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LoadingView();
          final result = snapshot.data!;
          if (result case Err(failure: final f)) {
            return ErrorView(message: f.message);
          }
          final b = (result as Success<BroadcastDetail>).value;
          _name = b.name;
          final texts = Theme.of(context).textTheme;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.campaign, color: Colors.white, size: 34),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(b.name, style: texts.titleLarge),
                    Text('${b.recipientCount} recipients',
                        style: texts.bodySmall?.copyWith(color: context.nexveero.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('RECIPIENTS',
                  style: texts.labelSmall?.copyWith(
                      color: context.nexveero.textSecondary, letterSpacing: 1)),
              const SizedBox(height: AppSpacing.sm),
              for (final u in b.recipients)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: AppAvatar(
                      name: u.name, imageUrl: MediaUrl.resolve(u.avatarUrl), size: 40),
                  title: Text(u.name),
                ),
            ],
          );
        },
      ),
    );
  }
}
