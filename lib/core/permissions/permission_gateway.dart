import 'package:permission_handler/permission_handler.dart';

/// Seam over the `permission_handler` static API so [PermissionManager] is
/// unit-testable without the platform channel. Production uses
/// [PermissionHandlerGateway]; tests inject a fake.
abstract class PermissionGateway {
  Future<PermissionStatus> status(Permission permission);
  Future<PermissionStatus> request(Permission permission);

  /// Opens the app's system settings page. Returns whether it opened.
  Future<bool> openSettings();
}

/// Default gateway backed by the real `permission_handler` package.
class PermissionHandlerGateway implements PermissionGateway {
  const PermissionHandlerGateway();

  @override
  Future<PermissionStatus> status(Permission permission) => permission.status;

  @override
  Future<PermissionStatus> request(Permission permission) =>
      permission.request();

  @override
  Future<bool> openSettings() => openAppSettings();
}
