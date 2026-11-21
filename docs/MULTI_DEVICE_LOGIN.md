# Concurrent device sessions

The app sends a stable, random installation identifier in `device_name`
(`android-<id>` or `ios-<id>`). It survives logout. Each installation stores
its own bearer token. This repository contains the Flutter client only.

Required backend behavior:
- Login issues an independent token without deleting other installations' tokens.
- Logout revokes only the token making the request (Sanctum currentAccessToken),
  rather than all tokens belonging to the user.
- Device registration retains multiple FCM tokens per user. Removing a device
  deletes only the submitted FCM token.
- Realtime supports multiple simultaneous connections for one user.

Verify against the deployed backend with two devices (including two Androids):
1. Login on A, then B using the same account. Both must access authenticated APIs.
2. Restart both apps; both must remain signed in.
3. Logout on A; B must still access APIs and receive notifications.
4. Login again on A; both must receive realtime updates and notifications.

Client regression tests cover login navigation, startup/login races, stale 401
responses, non-recursive session expiration, and installation identity persistence.
