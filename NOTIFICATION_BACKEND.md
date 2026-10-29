# Push notifications — backend setup (FCM direct)

The app now uses **Firebase Cloud Messaging (FCM) directly** — no OneSignal, no
third-party relay. Each device registers its FCM token with the backend, and the
backend sends notifications through the **Firebase Admin SDK (HTTP v1)** to those
tokens.

## What the mobile app already does
- Initializes Firebase at startup (`Firebase.initializeApp()`); Android reads the
  bundled `android/app/google-services.json` (wired by the `google-services`
  Gradle plugin), iOS reads `ios/Runner/GoogleService-Info.plist`.
- After login, requests notification permission, gets the FCM token and calls:

  ```
  POST /devices
  { "token": "<fcm-token>", "platform": "android" | "ios", "provider": "fcm" }
  ```
  It re-posts on token refresh. On logout it calls:
  ```
  DELETE /devices
  { "token": "<fcm-token>" }
  ```
- Routes a notification tap by `data.type` (values the app understands: `offer`,
  `order` / `order_created`, `approval`, `chat` / `chat_message`; anything else
  opens the notifications screen).

## 1. Backend: store device tokens
Add a `devices` table keyed by user: `{ user_id, token, platform, provider,
updated_at }`. On `POST /devices` upsert by `token` (one row per device token,
re-pointed to the current user). On `DELETE /devices` remove that token. Drop
tokens FCM reports as `UNREGISTERED` / `INVALID_ARGUMENT` when sending.

## 2. Backend: credentials
Use the **Firebase Service Account JSON** (Firebase console → Project settings →
Service accounts → *Generate new private key*) — the same project as the app's
`google-services.json` (project `nexveero-1e4f0`). Load it server-side with the
Firebase Admin SDK. No API key or REST secret is exposed to clients.

- **Android:** works out of the box with the Service Account (FCM v1).
- **iOS:** in Firebase console → Project settings → Cloud Messaging → **APNs
  Authentication Key**, upload an APNs `.p8` (Key ID + Team ID). Needs a paid
  Apple Developer account. Without this, iOS devices get no push.

## 3. Backend: send a notification (FCM Admin SDK, HTTP v1)
For each recipient, look up their device token(s) and send:

```jsonc
// POST https://fcm.googleapis.com/v1/projects/nexveero-1e4f0/messages:send
// Authorization: Bearer <OAuth token from the service account>
{
  "message": {
    "token": "<device-fcm-token>",
    "notification": { "title": "New message from Alice", "body": "Hey, is this available?" },
    "data": { "type": "chat", "conversation_id": "5", "load_id": "14" },
    "android": { "priority": "high" },
    "apns": { "payload": { "aps": { "sound": "default" } } }
  }
}
```
Most backends use the Admin SDK helper instead of raw HTTP, e.g. (Node):
```js
await admin.messaging().sendEachForMulticast({
  tokens: userTokens,
  notification: { title, body },
  data: { type: 'chat', conversation_id: String(id) }, // data values must be strings
});
```
Note: FCM `data` values must be **strings**. The app reads `data.type` to route.

## 4. Events that should trigger a push (recipients)
| Event | Notify | data.type |
|---|---|---|
| New chat message (1:1 / group) | the other participant(s) | `chat` (+ conversation_id) |
| New question on a post | the post owner | `chat` (+ conversation_id, load_id) |
| New offer on a post | the post owner | `offer` (+ conversation_id, load_id) |
| Post reported | all admins | `default` (or `report` + report_id) |
| Account approved | the user | `approval` |
| Broadcast message | each recipient | `chat` |
| Order status change | buyer/seller | `order` (+ order_id) |

## Notes
- Foreground notifications are already handled in-app over the socket
  (`message:new` etc.), so FCM is what covers **background / killed-app** delivery.
- Send `data` values as strings; put routing ids there so the app can deep-link.
- One provider only — the app is now FCM-only (OneSignal removed).
