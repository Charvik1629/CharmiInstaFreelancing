# Missing API Endpoints — Lyra

Design screens/buttons that have **no matching endpoint** in the uploaded API
docs (`/api/v1`). Everything else in the app is already wired to a documented
endpoint. Add these and the corresponding buttons light up with a one-line
repository change each (the screens, validation and state are already built).

**How to use this sheet:** every endpoint below has a **Purpose** (what it does +
which screen/action calls it) and a **Check existing** line (likely alternate
names / equivalents). Before building, scan the real backend for those aliases —
if the capability already exists under another path, just tell us the real path
and we re-point one line in `ApiEndpoints`; no screen changes needed.

Conventions (same as existing API): base `/api/v1`, `Authorization: Bearer {token}`,
`Accept: application/json`, payloads wrapped in `{ "data": ... }`, validation
errors as `422 { "message", "errors": { field: [..] } }`.

---

## 1. Auth — OTP verification
Design: "Verify it's you" (6-digit code).
**Purpose:** send a one-time code to an email/phone and verify it — used to
confirm a new account or a sensitive action. Called by the OTP screen
(`otp_verification_page`) "Send code" + "Verify".
**Check existing:** any of `verification`, `verify`, `otp`, `code`, `2fa`,
`confirm`, `email/verify`, `phone/verify`, `activation` routes.

- `POST /auth/otp/send` — body: `{ "identifier": "email-or-phone" }` → `200 { "data": { "expires_in": 60 } }`
- `POST /auth/otp/verify` — body: `{ "identifier": "...", "code": "123456" }` → `200 { "data": { "verified": true, "token": "..."? } }`
- Errors: `422` invalid/expired code, `429` too many attempts.

## 2. Auth — Forgot / reset password
Design: "Forgot password?" → "Send reset code" → set new password.
**Purpose:** let a logged-out user recover access — email a reset code, then set
a new password with it. Called by `forgot_password_page` (+ a reset step).
**Check existing:** `password/forgot`, `password/email`, `password/reset`,
`forgot-password`, `reset-password`, `password/reset-link`, Laravel's default
`/forgot-password` + `/reset-password`.

- `POST /auth/password/forgot` — body: `{ "email": "..." }` → `200 { "message": "If the account exists, a code was sent." }`
- `POST /auth/password/reset` — body: `{ "email": "...", "code": "123456", "password": "...", "password_confirmation": "..." }` → `200 { "message": "Password updated." }`
- Errors: `422` invalid code / weak password.

## 3. Auth — Change password (logged in)
Design: "Change password" (current / new / confirm).
**Purpose:** let a signed-in user change their password by confirming the
current one. Called by `change_password_page` (reached from the settings sheet).
**Check existing:** `password/change`, `password/update`, `account/password`,
`user/password`, `settings/password`, `profile/password`.

- `POST /auth/password/change` (auth) — body: `{ "current_password": "...", "password": "...", "password_confirmation": "..." }` → `200 { "message": "Password updated." }`
- Errors: `422` wrong current password / mismatch.

## 4. Creators — Suggested creators + Follow
Design: "Suggested creators" carousel with **Follow**.
**Purpose:** discover creators to follow (a "who to follow" list) and
follow/unfollow them; powers the feed's suggestions strip and follower counts.
No follow graph exists today (`GET /users?q=` is search only).
**Check existing:** `follow`, `following`, `followers`, `subscribe`,
`connections`, `users/suggested`, `creators/suggested`, `recommendations`,
`discover/creators`, `who-to-follow`.

- `GET /users/suggested` (auth) → `200 { "data": [ { user + "is_following": false } ], "meta": {...} }`
- `POST /users/{id}/follow` (auth) → `200 { "data": { "is_following": true, "followers_count": N } }`
- `DELETE /users/{id}/follow` (auth) → `200 { "data": { "is_following": false, "followers_count": N } }`
- Optional: `GET /users/{id}/followers`, `GET /users/{id}/following`.

## 5. Notifications — in-app list
Design: bell icon → notifications screen.
**Purpose:** show the in-app activity feed (requests, offers, follows, system
messages), a badge count, and mark-as-read. Only **FCM push** is documented
(`POST /devices`) — there's no way to *list* past notifications in-app.
**Check existing:** `notifications`, `alerts`, `activity`, `activities`,
`inbox`, `feed/activity`, `notifications/unread`, `notifications/mark-read`.

- `GET /notifications` (auth, paginated) → `200 { "data": [ { "id", "type", "title", "body", "read_at", "deep_link", "created_at" } ], "meta": {...} }`
- `GET /notifications/unread-count` (auth) → `200 { "data": { "count": N } }`
- `POST /notifications/{id}/read` (auth) → `200`
- `POST /notifications/read-all` (auth) → `200`

## 6. Create Post — multi-image, location & tags
Design "New post" shows a **multi-image** strip (numbered, reorderable), a
**Location** row ("Lisbon, Portugal") and an **Add tags** row.
**Purpose:** publish a post with a **gallery of photos** (ordered, first = cover),
an optional **place**, and searchable **tags/hashtags**. Today `POST /loads`
takes only a **single** `media` + `title` + `body` + `post_type_id`.
**Check existing:** on the create-load endpoint look for `media[]`, `images[]`,
`photos[]`, `attachments[]`, `gallery`; for place `location`, `place`,
`latitude`/`longitude`, `geo`, `city`; for tags `tags[]`, `hashtags[]`,
`tag_ids[]`, `labels[]`, `keywords`.

- Extend `POST /loads` (multipart) with:
  - `media[]` — `file[]` (ordered; first = cover). Response: `media: [{ url, mime, kind, position }]`.
  - `latitude`, `longitude` — `number` (optional) and/or `location_name` — `string`.
  - `tags[]` — `string[]` (or `tag_ids[]` if tags are a managed vocabulary).
- Until then the composer uploads only the first image; Location/Tags are shown
  as disabled "coming soon" rows.

## 7. Profile — posts count (and other stats)
Design "My Profile" shows a **"128 Posts"** stat.
**Purpose:** show how many posts (and ideally followers/following) a user has, on
their profile header — and, for a real grid, list *that user's* posts. Neither
`GET /auth/me` nor `GET /profile` returns any count, and `GET /loads` has no
author filter.
**Check existing:** a `posts_count` / `loads_count` / `stats` object on the
profile or user payload; or an author filter like `GET /loads?user_id=`,
`GET /loads?author=`, `GET /users/{id}/loads`, `GET /users/{id}/posts`.

- Add `posts_count` (and ideally `followers_count`, `following_count`) to the
  `/profile` and `/users/{id}` payloads, **or** expose
  `GET /users/{id}/loads` (paginated) so the profile can show the user's grid +
  a real count.

## 8. Account — delete account
Design "Delete account" ("This can't be undone").
**Purpose:** let a user permanently delete their own account + data from the
Settings screen. No endpoint exists.
**Check existing:** `DELETE /account`, `DELETE /users/me`, `POST /account/delete`,
`DELETE /auth/account`, `account/close`, `account/deactivate`.

- `DELETE /account` (auth, maybe body `{ "password": "..." }` or `{ "reason": "..." }`) → `200 { "message": "Account deleted." }`, then the app clears the session.

## 9. Orders — order request / create / details
Design has an **Orders** flow (Order request, Create order, Order details) with
per-order payment. No `/orders` resource exists in the API docs at all.
**Purpose:** turn an accepted offer/agreement into a payable order — buyer and
seller track an order through states (awaiting → paid → completed) with a
payable amount. Today the only money movement is **wallet credits**
(`/wallet/*`), which is a different concept (app currency, not per-order
payments).
**Check existing:** `/orders`, `/orders/{id}`, `orders/{id}/pay`, `/deals`,
`/bookings`, `/purchases`, `/transactions` (order-level, not wallet ledger), or
whether orders are modeled on top of `offers` + `wallet/checkout`.

- Likely needed: `GET /orders?tag=buying|selling`, `POST /orders` (from an
  offer/load), `GET /orders/{id}`, `POST /orders/{id}/pay` → payment intent.
- Until then the Orders screens are not built; **Wallet + Transactions are**.

> **Client note (not a missing API):** `POST /wallet/checkout` + `/wallet/verify`
> exist, but completing a purchase needs the **Razorpay Flutter SDK + live
> keys** on device. The dev wallet reports `razorpay_configured=false`, so the
> Buy button is gated. Wire `razorpay_flutter` + real keys to enable it (or use
> the `demo_topup` path if the backend exposes a demo-credit endpoint).

---

## Partially covered (endpoints exist — confirm the exact path/params)
Each has a **Purpose** so you can confirm the documented endpoint truly covers it.

- **Search** (bottom-nav).
  **Purpose:** one search box over people + posts (+ offers) with recents/results.
  Reuse `GET /users?q=` (people) and `GET /loads?post_type=` / `GET /offers?q=`
  (content). **Check existing:** a unified `GET /search?q=` (people+posts+tags) —
  nicer if it exists, otherwise the app fans out to the per-resource endpoints.
- **Marketplace / Storefront** (bottom-nav).
  **Purpose:** the business/shop feed. Use `GET /loads?post_type=business`.
  **Check existing:** `marketplace`, `storefront`, `shop`, `business`,
  `loads?type=business` — confirm the `post_type` slug value ("business").
- **Profile photo / phone** (Register & Profile).
  **Purpose:** set avatar + phone. Covered by `PUT|POST /profile` (multipart).
- **Create post / Boost / Wallet / Chat / Groups / Offers / Broadcasts / Reports**:
  all have documented endpoints — wired in their modules.

## Status in app today
Screens for #1–#3 are **built and fully wired** to the endpoints above (see
`ApiEndpoints` + `AuthRepository`). The buttons make real calls now; until the
backend implements these paths they simply return an error (shown as a normal
snackbar) — no placeholder UI is shipped. #4 (suggested creators), #5
(notifications), #6 (multi-image/location/tags) and #7 (profile counts) are
shown as gated "coming soon" affordances and light up once the endpoints exist.
