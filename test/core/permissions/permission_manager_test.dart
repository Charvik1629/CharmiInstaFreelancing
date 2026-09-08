import 'package:charmi_insta_freelancing/core/permissions/app_permission.dart';
import 'package:charmi_insta_freelancing/core/permissions/permission_gateway.dart';
import 'package:charmi_insta_freelancing/core/permissions/permission_manager.dart';
import 'package:charmi_insta_freelancing/core/permissions/permission_outcome.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

/// Scriptable gateway: returns queued statuses and records interactions so we
/// can assert whether the manager actually prompted.
class _FakeGateway implements PermissionGateway {
  _FakeGateway({required this.initialStatus, PermissionStatus? afterRequest})
      : requestStatus = afterRequest ?? initialStatus;

  final PermissionStatus initialStatus;
  final PermissionStatus requestStatus;

  int statusCalls = 0;
  int requestCalls = 0;
  int settingsCalls = 0;

  @override
  Future<PermissionStatus> status(Permission permission) async {
    statusCalls++;
    return initialStatus;
  }

  @override
  Future<PermissionStatus> request(Permission permission) async {
    requestCalls++;
    return requestStatus;
  }

  @override
  Future<bool> openSettings() async {
    settingsCalls++;
    return true;
  }
}

void main() {
  group('PermissionOutcome.fromStatus', () {
    test('maps every SDK status', () {
      expect(PermissionOutcome.fromStatus(PermissionStatus.granted),
          PermissionOutcome.granted);
      expect(PermissionOutcome.fromStatus(PermissionStatus.provisional),
          PermissionOutcome.granted);
      expect(PermissionOutcome.fromStatus(PermissionStatus.limited),
          PermissionOutcome.limited);
      expect(PermissionOutcome.fromStatus(PermissionStatus.denied),
          PermissionOutcome.denied);
      expect(PermissionOutcome.fromStatus(PermissionStatus.permanentlyDenied),
          PermissionOutcome.permanentlyDenied);
      expect(PermissionOutcome.fromStatus(PermissionStatus.restricted),
          PermissionOutcome.restricted);
    });

    test('isUsable is true only for granted and limited', () {
      expect(PermissionOutcome.granted.isUsable, isTrue);
      expect(PermissionOutcome.limited.isUsable, isTrue);
      expect(PermissionOutcome.denied.isUsable, isFalse);
      expect(PermissionOutcome.permanentlyDenied.isUsable, isFalse);
      expect(PermissionOutcome.restricted.isUsable, isFalse);
    });

    test('requiresSettings is true only for permanentlyDenied and restricted',
        () {
      expect(PermissionOutcome.permanentlyDenied.requiresSettings, isTrue);
      expect(PermissionOutcome.restricted.requiresSettings, isTrue);
      expect(PermissionOutcome.denied.requiresSettings, isFalse);
      expect(PermissionOutcome.granted.requiresSettings, isFalse);
      expect(PermissionOutcome.limited.requiresSettings, isFalse);
    });
  });

  group('PermissionManager.status', () {
    test('reports outcome without prompting', () async {
      final gw = _FakeGateway(initialStatus: PermissionStatus.denied);
      final manager = PermissionManager(gw);

      final outcome = await manager.status(AppPermission.contacts);

      expect(outcome, PermissionOutcome.denied);
      expect(gw.statusCalls, 1);
      expect(gw.requestCalls, 0);
    });
  });

  group('PermissionManager.ensure', () {
    test('already granted -> returns granted without prompting', () async {
      final gw = _FakeGateway(initialStatus: PermissionStatus.granted);
      final manager = PermissionManager(gw);

      final outcome = await manager.ensure(AppPermission.camera);

      expect(outcome, PermissionOutcome.granted);
      expect(gw.requestCalls, 0);
    });

    test('limited access is treated as usable and not re-prompted', () async {
      final gw = _FakeGateway(initialStatus: PermissionStatus.limited);
      final manager = PermissionManager(gw);

      final outcome = await manager.ensure(AppPermission.photos);

      expect(outcome, PermissionOutcome.limited);
      expect(outcome.isUsable, isTrue);
      expect(gw.requestCalls, 0);
    });

    test('denied -> prompts once and returns the granted result', () async {
      final gw = _FakeGateway(
        initialStatus: PermissionStatus.denied,
        afterRequest: PermissionStatus.granted,
      );
      final manager = PermissionManager(gw);

      final outcome = await manager.ensure(AppPermission.contacts);

      expect(outcome, PermissionOutcome.granted);
      expect(gw.requestCalls, 1);
    });

    test('denied -> user denies again stays denied', () async {
      final gw = _FakeGateway(
        initialStatus: PermissionStatus.denied,
        afterRequest: PermissionStatus.denied,
      );
      final manager = PermissionManager(gw);

      final outcome = await manager.ensure(AppPermission.microphone);

      expect(outcome, PermissionOutcome.denied);
      expect(gw.requestCalls, 1);
    });

    test('permanentlyDenied -> does NOT prompt (would be a no-op)', () async {
      final gw = _FakeGateway(initialStatus: PermissionStatus.permanentlyDenied);
      final manager = PermissionManager(gw);

      final outcome = await manager.ensure(AppPermission.contacts);

      expect(outcome, PermissionOutcome.permanentlyDenied);
      expect(outcome.requiresSettings, isTrue);
      expect(gw.requestCalls, 0);
    });

    test('restricted -> does NOT prompt', () async {
      final gw = _FakeGateway(initialStatus: PermissionStatus.restricted);
      final manager = PermissionManager(gw);

      final outcome = await manager.ensure(AppPermission.contacts);

      expect(outcome, PermissionOutcome.restricted);
      expect(gw.requestCalls, 0);
    });
  });

  group('PermissionManager.openSettings', () {
    test('delegates to the gateway', () async {
      final gw = _FakeGateway(initialStatus: PermissionStatus.permanentlyDenied);
      final manager = PermissionManager(gw);

      final opened = await manager.openSettings();

      expect(opened, isTrue);
      expect(gw.settingsCalls, 1);
    });
  });

  group('AppPermission mapping', () {
    test('each app permission maps to a handler permission', () {
      expect(AppPermission.contacts.handlerPermission, Permission.contacts);
      expect(AppPermission.camera.handlerPermission, Permission.camera);
      expect(AppPermission.photos.handlerPermission, Permission.photos);
      expect(AppPermission.microphone.handlerPermission, Permission.microphone);
      expect(
          AppPermission.notification.handlerPermission, Permission.notification);
    });
  });
}
