# Nexveero — Codebase Guide

A map of the whole Flutter app so that, given any issue, you (or an AI like
ChatGPT / Claude) can quickly find **which file(s)** to look at and fix.

> **How to use this with an AI:** paste this whole file, describe your issue
> (what screen, what behaviour is wrong). The AI will tell you the likely file
> from the maps below. Then open that file and paste its contents to get a fix.
> For most issues you need **3 files**: the **page** (UI), its **cubit** (logic),
> and the **repository / remote data source** (API call). See "Issue → files".

---

## 1. What the app is

Nexveero is a B2B marketplace + chat app (Flutter, Android/iOS). Users post
Buy/Sell/Business listings in a feed, request/offer/ask on posts, chat 1:1 and
in groups, send broadcasts, manage a business profile, wallet/credits, and
admin tooling. Backend is a REST API at `https://nexveero.com/api/v1`
(see API docs at `https://nexveero.com/api-docs.html`).

## 2. Tech stack

- **Flutter** + Dart 3.
- **State management:** `flutter_bloc` **Cubit** (one cubit per screen/flow).
- **DI:** `get_it` — the single registry is `lib/core/di/injection.dart` (`sl`).
- **Routing:** `go_router` — all routes in `lib/core/router/app_router.dart`,
  route-name constants in `lib/core/router/app_routes.dart`.
- **Networking:** `dio` wrapped by `lib/core/network/api_client.dart`.
- **Realtime:** Socket.IO (`lib/core/realtime/socket_service.dart`).
- **Push:** FCM-direct (`lib/core/push/push_service.dart`).
- **Local storage:** `flutter_secure_storage` (token) + `shared_preferences`,
  both behind `lib/core/storage/storage_manager.dart`.
- **Maps:** `google_maps_flutter` + Places API (New) HTTP calls.

## 3. Architecture (how data flows)

Clean architecture, 3 layers per feature:

```
UI (pages/widgets)  →  Cubit (presentation/cubit)  →  Repository (domain)
                                                         ↓  implemented by
                                             Repository Impl (data/repositories)
                                                         ↓  calls
                                      Remote Data Source (data/datasources)
                                                         ↓  uses
                                          ApiClient (core/network/api_client)
```

- A **page** builds UI and calls methods on its **cubit**.
- The **cubit** holds state (a `*_state.dart` part file) and calls the
  **repository** (an abstract interface in `domain/repositories/`).
- The **repository impl** (`data/repositories/`) calls a **remote data source**
  (`data/datasources/`) which hits the API via `ApiClient`.
- Results are wrapped in `Result<T>` = `Success` | `Err` (`lib/core/utils/result.dart`).
- Errors become typed `Failure`s (`lib/core/error/failure.dart`) via `BaseRepository.guard()`
  (`lib/core/network/base_repository.dart`).

**So a typical bug lives in one of:** the page (UI/layout/navigation), the cubit
(logic/state), the data source (wrong endpoint/params/parsing), or a model
(`*/domain/entities/*` or `lib/core/models/*` — JSON parsing).

---

## 4. Issue → files (lookup)

| If the issue is about… | Look in |
|---|---|
| **Login / logout / session lost / stays logged out** | `features/auth/presentation/cubit/auth_cubit.dart`, `features/auth/data/repositories/auth_repository_impl.dart`, `core/storage/storage_manager.dart` (token persistence), `core/network/auth_interceptor.dart` (401 → logout) |
| **Which screen opens / navigation / back button / redirects** | `core/router/app_router.dart` (routes + auth redirect), `core/router/app_routes.dart` |
| **Bottom nav tabs / tab order / app opens on wrong tab** | `features/shell/presentation/home_shell.dart` |
| **Feed list / post card / Buy-Sell badge / search in feed** | `features/feed/presentation/pages/feed_page.dart`, `features/feed/presentation/widgets/post_card.dart`, `features/feed/presentation/cubit/feed_cubit.dart`, `features/feed/data/datasources/feed_remote_data_source.dart` |
| **Post detail / delete / edit / boost / mark sold** | `features/feed/presentation/pages/post_detail_page.dart` + the same `post_card.dart` + `feed_cubit.dart` |
| **Create / edit a post** | `features/feed/presentation/pages/create_post_page.dart`, `features/feed/presentation/cubit/create_post_cubit.dart` |
| **Chat list / inbox / chat search / filters / labels filter row** | `features/chat/presentation/pages/chat_list_page.dart`, `features/chat/presentation/cubit/chat_list_cubit.dart` |
| **Chat thread (messages screen) / bubbles / time / ticks / composer / quick replies / location send / labels dot** | `features/chat/presentation/pages/chat_thread_page.dart`, `features/chat/presentation/cubit/conversation_cubit.dart` |
| **Message send / read receipts / mark read / API for messages** | `conversation_cubit.dart` + `features/chat/data/datasources/chat_remote_data_source.dart` + `features/chat/data/repositories/chat_repository_impl.dart` |
| **Unread badge** | `features/chat/presentation/cubit/unread_cubit.dart` |
| **Chat labels (create / assign / remove)** | `features/chat/presentation/pages/manage_labels_page.dart`, `chat_labels_cubit.dart`, label logic in `chat_list_cubit.dart` + `chat_thread_page.dart` |
| **Send / view location on map / place search** | `features/chat/presentation/pages/location_picker_page.dart` (search + current location), `location_view_page.dart` (view), `core/config/maps_config.dart` (API key) |
| **Groups / create group / join / members** | `features/groups/presentation/pages/*` (`groups_list_page`, `create_group_page`, `group_detail_page`), `groups/presentation/cubit/*`, `groups/data/datasources/groups_remote_data_source.dart` |
| **Broadcasts (list / create / quota)** | `features/broadcasts/presentation/pages/*`, `create_broadcast_cubit.dart`, `broadcasts_remote_data_source.dart`; admin: `features/admin/.../admin_broadcast_groups_page.dart`, `broadcast_groups_cubit.dart` |
| **Business feed / business directory** | `features/business/presentation/pages/business_feed_page.dart` (uses `feed_cubit`), `business_directory_page.dart`, `business/data/...` |
| **Profile (own / user / business) / avatar enlarge / edit profile** | `features/profile/presentation/pages/*` (`profile_page`, `user_profile_page`, `business_profile_page`, `edit_profile_page`), `profile/presentation/cubit/*` |
| **Search tab (people search)** | `features/search/presentation/pages/search_page.dart`, `search_cubit.dart`, `search_remote_data_source.dart` (GET /users?q=) |
| **Offers (make / list)** | `features/offers/...` |
| **Orders** | `features/orders/...` |
| **Wallet / credits / transactions / payment** | `features/wallet/...`, `features/payment/...` |
| **Subscription / plans** | `features/subscription/...` |
| **Notifications list** | `features/notifications/...` |
| **Contact sync / find friends / invite** | `features/contacts/presentation/pages/contact_sync_page.dart`, `contact_sync_cubit.dart`, `contacts_remote_data_source.dart` |
| **Settings / change password / security / chat PIN / delete account** | `features/settings/...`, `features/security/...`, `features/auth/presentation/pages/change_password_page.dart` |
| **Admin (users / reports / packages / pricing / tags / subscriptions)** | `features/admin/...`, `features/tags/...`, `features/subscription/.../admin_*` |
| **Push notification not opening app / tapped notification** | `core/push/push_service.dart`, `android/app/src/main/AndroidManifest.xml` (intent-filters) |
| **Realtime / live messages / presence / "online"** | `core/realtime/socket_service.dart`, `core/realtime/presence_observer.dart` |
| **Colors / dark mode / spacing / fonts / theme** | `core/theme/*` (`app_colors`, `app_theme`, `app_spacing`, `app_typography`, `theme_cubit`) |
| **Shared widgets (avatar, button, bottom nav, loader, image viewer, chips)** | `core/widgets/*` (barrel: `widgets.dart`) |
| **An API call: wrong URL / params / headers / auth token** | `core/constants/api_endpoints.dart` (paths), the feature's `*_remote_data_source.dart`, `core/network/api_client.dart`, `core/network/auth_interceptor.dart` |
| **JSON parsing / a field not showing / null field** | the model: `core/models/*` (`load`, `user`, `author`, `post_type`) or the feature's `domain/entities/*`; helpers in `core/extensions/json_extensions.dart` |
| **Base URL / environment / Maps key** | `core/config/app_config.dart`, `core/config/maps_config.dart` |

---

## 5. Core infrastructure files

- **`core/di/injection.dart`** — registers every repository, data source, and
  cubit with `get_it`. If a new cubit/repo isn't resolving, register it here.
- **`core/network/api_client.dart`** — the dio wrapper (GET/POST/PUT/DELETE, base
  URL, timeouts, error mapping).
- **`core/network/auth_interceptor.dart`** — attaches `Authorization: Bearer
  <token>`; on **401** clears the session and triggers logout (the `onUnauthorized`
  callback wired in `lib/main.dart`).
- **`core/network/base_repository.dart`** — `guard()` wraps data-source calls and
  maps exceptions to typed `Failure`s; also short-circuits with `ConfigFailure`
  if the base URL is a placeholder.
- **`core/network/api_response.dart`** — `PaginatedResponse`, `PaginationMeta`,
  `ApiEnvelope.list/object` (unwrap `{data, meta}`).
- **`core/storage/storage_manager.dart`** — token + prefs. Secure values are
  mirrored to SharedPreferences so the session survives app restarts even when
  the Android Keystore is unreliable (OPPO/ColorOS). Keys in `storage_keys.dart`.
- **`core/router/app_router.dart`** — all `GoRoute`s + `_redirect` (auth gating:
  unauthenticated → login, authenticated → feed).
- **`core/realtime/socket_service.dart`** — Socket.IO connect/reconnect; emits
  streams (`messages`, `unreadUpdates`, `connected`, …) that cubits listen to.
- **`core/push/push_service.dart`** — FCM token, foreground/background
  notification handling, tapping a notification routes to the chat.
- **`core/utils/result.dart`** — `Result<T>` / `Success` / `Err`.
- **`core/error/failure.dart`** — `Failure` types (Network, Auth, Validation,
  Config, InsufficientCredits, Unknown…). `app_exception.dart` = raw exceptions.
- **`core/models/`** — shared models: `user.dart`, `load.dart` (a feed post),
  `author.dart` (embedded user ref), `post_type.dart`.
- **`main.dart`** (lib root) — app bootstrap: DI init, AuthCubit, router.

---

## 6. Features (purpose + files)

Each feature follows `data/` (datasources + repositories impl), `domain/`
(entities + repository interfaces), `presentation/` (pages + cubit + widgets).
Only the most useful files are listed; a feature's folder has the rest.

- **auth** — login, register, OTP, forgot/change password, onboarding, splash,
  pending approval. `auth_cubit.dart` (session), `login_cubit.dart`,
  `register_cubit.dart`, `auth_repository_impl.dart`, `auth_remote_data_source.dart`.
- **shell** — the logged-in app shell with the bottom nav + IndexedStack of tabs:
  `home_shell.dart`.
- **feed** — the Home feed of posts, create/edit post, post detail, shared
  post links. `feed_page.dart`, `post_card.dart` (the card), `post_detail_page.dart`,
  `create_post_page.dart`, `feed_cubit.dart`, `create_post_cubit.dart`,
  `feed_remote_data_source.dart`.
- **chat** — inbox, 1:1/group/broadcast threads, labels, starred, location,
  contact info, chat PIN. `chat_list_page.dart`, `chat_thread_page.dart`,
  `conversation_cubit.dart`, `chat_list_cubit.dart`, `unread_cubit.dart`,
  `chat_labels_cubit.dart`, `chat_remote_data_source.dart`.
- **groups** — list/recommended, create, detail, members, join requests.
- **broadcasts** — user broadcast list + create; admin broadcast groups live in
  **admin**.
- **business** — Business feed (reuses `feed_cubit` with a fixed type) +
  business directory (find businesses).
- **profile** — own profile, other user profile, business profile, edit profile,
  business details.
- **search** — people search tab (GET /users?q=).
- **offers / orders / wallet / payment / subscription** — commerce flows.
- **notifications** — in-app notification list.
- **contacts** — contact sync (find friends, invite).
- **settings / security** — settings, change password, chat PIN, delete account.
- **admin / tags / post_types / status** — admin tooling, tag management, post
  types, status page.

---

## 7. Common change recipes (which files to touch together)

- **Add a field to a post card / fix a field not showing:** the model
  (`core/models/load.dart` — parse it in `fromJson`) + the UI
  (`features/feed/presentation/widgets/post_card.dart`).
- **Add/parse a new API field anywhere:** the entity/model `fromJson` + wherever
  it's shown. If it's sent, also the `*_remote_data_source.dart` body.
- **Change what an API call sends/returns:** `*_remote_data_source.dart` (+ the
  repository interface/impl if the signature changes + the cubit that calls it).
- **New screen:** page + cubit (+ state) + repository + data source, register
  the cubit/repo in `injection.dart`, add a route in `app_router.dart` +
  `app_routes.dart`.
- **Search that filters a list via the API:** add a `q` param down the chain
  (data source → repository → cubit `setSearch` with a debounce) and wire the
  search field's `onChanged` to it (see `feed_cubit.dart` / `chat_list_cubit.dart`).

---

## 8. Backend gaps (can't be fixed app-side alone)

- **Post price:** `GET /loads` returns **no price field**, so posts can't show a
  price until the backend adds one.
- **Broadcast Active/Archived status:** `GET /broadcasts` has no status/archive
  field (broadcast message/list **quota** IS available via `meta.broadcast_*_quota`).

---

*Generated to help locate issues quickly. File paths are relative to the repo
root (prepend `lib/` where a path starts with `features/` or `core/`).*
