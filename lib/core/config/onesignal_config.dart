/// OneSignal push configuration.
///
/// SETUP (one-time):
/// 1. Create a free app at https://onesignal.com → "New App/Website" → Android
///    (and iOS later). Copy the **App ID** (Settings → Keys & IDs).
/// 2. Paste it into [appId] below.
/// 3. In the OneSignal dashboard, connect Android push: upload your Firebase
///    **Service Account JSON** (FCM v1). OneSignal talks to FCM on the server
///    side, so the app itself does NOT need firebase_core / google-services.json
///    — which is exactly why this avoids the Gradle build wall.
/// 4. Backend: to send a push, call the OneSignal REST API targeting the user's
///    external id (we set it to the Nexveero user id on login) instead of
///    `POST /devices`/FCM. (Relay to the backend team.)
class OneSignalConfig {
  OneSignalConfig._();

  /// Your OneSignal App ID. Push is a no-op until this is filled in.
  static const String appId = 'YOUR_ONESIGNAL_APP_ID';

  static bool get isConfigured =>
      appId.isNotEmpty && appId != 'YOUR_ONESIGNAL_APP_ID';
}
