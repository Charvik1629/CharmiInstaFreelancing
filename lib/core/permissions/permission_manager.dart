import '../utils/logger.dart';
import 'app_permission.dart';
import 'permission_gateway.dart';
import 'permission_outcome.dart';

/// Reusable runtime-permission manager. Every feature that needs a device
/// permission goes through this instead of touching `permission_handler`
/// directly, so prompt/settings behavior stays consistent app-wide.
///
/// Typical use:
/// ```dart
/// final outcome = await sl<PermissionManager>().ensure(AppPermission.contacts);
/// if (outcome.isUsable) { /* read contacts */ }
/// else if (outcome.requiresSettings) { /* offer "Open settings" */ }
/// ```
class PermissionManager {
  const PermissionManager([
    PermissionGateway gateway = const PermissionHandlerGateway(),
  ]) : _gateway = gateway;

  final PermissionGateway _gateway;

  /// Current status without prompting.
  Future<PermissionOutcome> status(AppPermission permission) async {
    final status = await _gateway.status(permission.handlerPermission);
    return PermissionOutcome.fromStatus(status);
  }

  /// Ensures [permission] is available: returns immediately if it is already
  /// usable, or already permanently blocked (prompting there is a no-op that
  /// only confuses the user); otherwise it prompts once and returns the result.
  Future<PermissionOutcome> ensure(AppPermission permission) async {
    final current = await status(permission);
    if (current.isUsable || current.requiresSettings) {
      return current;
    }
    final result = await _gateway.request(permission.handlerPermission);
    final outcome = PermissionOutcome.fromStatus(result);
    AppLogger.d(
      'Permission ${permission.name} -> ${outcome.name}',
      tag: 'Permissions',
    );
    return outcome;
  }

  /// Opens the system Settings page for the app. Use when [ensure] returns an
  /// outcome whose [PermissionOutcome.requiresSettings] is true.
  Future<bool> openSettings() => _gateway.openSettings();
}
