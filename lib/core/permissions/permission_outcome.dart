import 'package:permission_handler/permission_handler.dart';

/// Normalized result of a permission check/request. Collapses the SDK's finer
/// states into the four the UI actually branches on, plus [limited] for iOS
/// partial photo access (which is still usable).
enum PermissionOutcome {
  /// Fully granted — proceed.
  granted,

  /// Denied this time, but the OS will prompt again next request.
  denied,

  /// Denied for good ("Don't ask again" / iOS second denial). The only way
  /// back is the system Settings screen — see [requiresSettings].
  permanentlyDenied,

  /// Blocked by device policy (parental controls / MDM). Not user-recoverable
  /// from a prompt.
  restricted,

  /// iOS "limited" photo selection — partial but usable access.
  limited;

  /// Maps a raw [PermissionStatus] onto an outcome. Exhaustive so a new SDK
  /// status surfaces as a compile error rather than a silent mis-map.
  static PermissionOutcome fromStatus(PermissionStatus status) =>
      switch (status) {
        PermissionStatus.granted => PermissionOutcome.granted,
        PermissionStatus.provisional => PermissionOutcome.granted,
        PermissionStatus.limited => PermissionOutcome.limited,
        PermissionStatus.permanentlyDenied =>
          PermissionOutcome.permanentlyDenied,
        PermissionStatus.restricted => PermissionOutcome.restricted,
        PermissionStatus.denied => PermissionOutcome.denied,
      };

  /// The app may access the resource (full or limited access).
  bool get isUsable =>
      this == PermissionOutcome.granted || this == PermissionOutcome.limited;

  /// Re-prompting is pointless; the user must change it in Settings.
  bool get requiresSettings =>
      this == PermissionOutcome.permanentlyDenied ||
      this == PermissionOutcome.restricted;
}
