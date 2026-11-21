import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/realtime/socket_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../admin/domain/repositories/admin_repository.dart';

/// Mounted only in the admin menu. A failed request leaves the count unknown.
class UserApprovalsTile extends StatefulWidget {
  const UserApprovalsTile({super.key, this.refresh});

  final ValueListenable<int>? refresh;

  @override
  State<UserApprovalsTile> createState() => _UserApprovalsTileState();
}

class _UserApprovalsTileState extends State<UserApprovalsTile>
    with WidgetsBindingObserver {
  int? _count;
  int _revision = 0;
  StreamSubscription<NotificationEvent>? _notifications;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.refresh?.addListener(_load);
    if (sl.isRegistered<SocketService>()) {
      _notifications = sl<SocketService>().notifications.listen((event) {
        if (event.type == 'user_pending') _load();
      });
    }
    _load();
  }

  @override
  void didUpdateWidget(UserApprovalsTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refresh != widget.refresh) {
      oldWidget.refresh?.removeListener(_load);
      widget.refresh?.addListener(_load);
    }
  }

  Future<void> _load() async {
    final revision = ++_revision;
    final result = await sl<AdminRepository>().pendingUsersCount();
    if (!mounted || revision != _revision) return;
    setState(() => _count = result.valueOrNull);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.refresh?.removeListener(_load);
    _notifications?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.how_to_reg_outlined,
        color: context.nexveero.textSecondary,
      ),
      title: const Text('User approvals'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_count != null) ...[
            Semantics(
              label: '$_count pending user approvals',
              child: ExcludeSemantics(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 26),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_count',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      onTap: () async {
        await context.push(AppRoutes.adminUsers);
        if (mounted) await _load();
      },
    );
  }
}
