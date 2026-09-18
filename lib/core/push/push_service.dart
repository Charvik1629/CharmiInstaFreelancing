import '../network/api_client.dart';

/// Push notifications (Firebase Cloud Messaging).
///
/// TEMPORARILY STUBBED. `firebase_core` cannot build under the project's pinned
/// Android toolchain (AGP 8.11.1 + Gradle 8.14.4 + Flutter's built-in Kotlin):
/// `:firebase_core:compileDebugJavaWithJavac` fails with *"Cannot query the
/// value of this provider because it has no value available"* — an AGP/plugin
/// incompatibility that hits both firebase_core 3.x and 4.x. So the Firebase
/// deps are commented out in pubspec and the call sites (main/auth) run as
/// no-ops. The real FCM implementation lives in git commit `10d7040`
/// (`lib/core/push/push_service.dart` + `lib/firebase_options.dart`); restore it
/// once the toolchain builds firebase_core. `google-services.json` and the
/// backend `POST /devices` endpoint are already in place.
class PushService {
  PushService(this._client);

  // ignore: unused_field
  final ApiClient _client;

  /// No-op until Firebase is re-enabled.
  static Future<void> initFirebase() async {}

  /// No-op until Firebase is re-enabled.
  Future<void> start() async {}

  /// No-op until Firebase is re-enabled.
  Future<void> unregister() async {}
}
