import 'package:flutter/material.dart';

import '../di/injection.dart';
import '../widgets/app_overlays.dart';
import 'app_permission.dart';
import 'permission_manager.dart';
import 'permission_outcome.dart';

/// UI-facing convenience that runs the full permission handshake for a feature:
/// request the permission and, when it's permanently blocked, offer to open the
/// system Settings. Keeps the "denied -> settings" pattern in one place so every
/// call site behaves the same.
class PermissionFlow {
  PermissionFlow._();

  /// Ensures [permission], showing a Settings redirect dialog if the OS won't
  /// prompt any more. Returns the final [PermissionOutcome]; callers check
  /// [PermissionOutcome.isUsable]. Safe against an unmounted context.
  static Future<PermissionOutcome> ensure(
    BuildContext context,
    AppPermission permission, {
    String? rationaleTitle,
    String? rationaleMessage,
  }) async {
    final outcome = await sl<PermissionManager>().ensure(permission);

    if (outcome.requiresSettings && context.mounted) {
      final go = await AppOverlays.confirm(
        context,
        title: rationaleTitle ?? 'Permission needed',
        message: rationaleMessage ??
            'Enable ${_label(permission)} access in Settings to continue.',
        confirmLabel: 'Open settings',
      );
      if (go) {
        await sl<PermissionManager>().openSettings();
      }
    }
    return outcome;
  }

  static String _label(AppPermission permission) => switch (permission) {
        AppPermission.contacts => 'contacts',
        AppPermission.camera => 'camera',
        AppPermission.photos => 'photos',
        AppPermission.microphone => 'microphone',
        AppPermission.notification => 'notifications',
      };
}
