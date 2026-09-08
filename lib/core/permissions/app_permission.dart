import 'package:permission_handler/permission_handler.dart';

/// App-level permissions, decoupled from the underlying `permission_handler`
/// package so the rest of the app never imports the SDK directly (same policy
/// as [AdService]). Add a case here when a new capability needs a runtime
/// permission, and wire the matching platform config (AndroidManifest +
/// Info.plist / Podfile macros).
enum AppPermission {
  /// Device contacts — required by Contact Sync (Module 8).
  contacts,

  /// Camera capture for creating a post with a photo/video.
  camera,

  /// Photo library / gallery access for attaching media to a post.
  photos,

  /// Microphone for video posts.
  microphone,

  /// Push / local notifications (Android 13+ and iOS ask at runtime).
  notification;

  /// The concrete `permission_handler` permission this maps to.
  Permission get handlerPermission => switch (this) {
        AppPermission.contacts => Permission.contacts,
        AppPermission.camera => Permission.camera,
        AppPermission.photos => Permission.photos,
        AppPermission.microphone => Permission.microphone,
        AppPermission.notification => Permission.notification,
      };
}
