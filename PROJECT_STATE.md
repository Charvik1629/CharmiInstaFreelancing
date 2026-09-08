# Project State — Lyra (charmi_insta_freelancing)

> Read this FIRST at the start of every session. Continue from **Next Step**. Do not redo completed work.

## Current Phase
Module 9 (all remaining screens) — **effectively ALL design screens now built.**
Verified-live set: Feed, Create Post, Profile, Edit Profile, Chats (inbox +
thread, 3 types), Search, Marketplace, Settings, Notifications, Offers, Wallet,
Transactions. **Built but NOT YET compiler-verified** (Flutter SDK went missing
mid-build — see BLOCKER): Admin (Reported posts / Packages / Pricing), Groups
(list + detail), Security (chat PIN), Creator/other-user Profile, Broadcasts
(create + detail), Orders (list/create/detail — gated, no API), Payment (method
screen + result dialogs — gated), Post Detail (+ Ask-a-question dialog).

## BLOCKER RESOLVED — Flutter restored & batch verified
The SDK had gone missing during a usage-limit pause; re-cloned to
`~/development/flutter` (Flutter 3.47.2 stable / Dart 3.13.2). After restore:
`flutter analyze` = **No issues found**, `flutter test` = **168 pass**. Fixes
applied: 2 wrong import-path depths in `security/`, 1 unused import in
broadcast_detail_page. The whole last batch compiles. STILL TO DO: (a) add cubit
tests for the new features (Admin/Groups/Security/Broadcasts) to keep the
per-module test standard; (b) live-verify the new screens on the emulator (it
stopped when the SDK vanished — reboot + restart the scratch mock_api.py).
Prefix flutter with `export PATH="$HOME/development/flutter/bin:$PATH"`.

## Status
IN PROGRESS

## Module Status
| # | Module | Status |
|---|--------|--------|
| 1 | Project setup & architecture | COMPLETE |
| 2 | Theme & common components | COMPLETE |
| 3 | API / network layer | COMPLETE |
| 4 | Auth & onboarding | COMPLETE |
| 5 | Feed / Post Listing (loads) | COMPLETE |
| 6 | Google Ads in feed | COMPLETE |
| 7 | Runtime Permission Manager | COMPLETE |
| 8 | Contact Sync | PENDING (API not available — payload only) |
| 9 | Remaining screens | PENDING |
| 10 | Integration & testing | PENDING |
| 11 | Final cleanup / refactor | PENDING |

## Important Decisions
- App name: **Lyra**. Design "posts/feed" == API "loads" resource.
- Base URL is **centralized** in `lib/core/config/app_config.dart`; real value NOT yet provided → placeholder. Change in ONE place later.
- State mgmt: flutter_bloc (Cubit). DI: get_it. Router: go_router. HTTP: dio. Token store: flutter_secure_storage.
- Ad frequency centralized in `lib/core/constants/ad_config.dart`.
- Theme: Aurora Bloom (violet→magenta), light+dark. Fonts: Sora + Plus Jakarta Sans.

## API / Base URL status
- Base URL: **UNKNOWN** — placeholder in AppConfig; inject via
  `--dart-define=BASE_URL=...` when the real URL is ready (no code change).
- Contact-sync API: **not available** — build payload generation only.

## Known Issues
- iOS toolchain: xcode-select points at CommandLineTools; CocoaPods not installed (user must run — needs sudo). iOS plugin builds blocked until then. Android is fine.

## Last Completed Task
- **Module 8 — Contact Sync DONE (the last remaining module).** analyze clean;
  **178 tests pass** (+10). `lib/features/contacts/`: `ContactNormalizer`
  (phone → `+digits`, dedupe key = last 10 digits, email lowercase/validate),
  `DeviceContact` + `ContactSyncPayload.fromDevice` (drops un-syncable, dedupes
  by phone/email), `ContactsDataSource` (reads via **flutter_contacts 2.3.1
  `FlutterContacts.getAll(properties: {ContactProperty.phone, .email})`** — note
  the 2.3.x API is `getAll`, not `getContacts`, and `displayName` is nullable),
  `ContactsRepository` (buildPayload works; **upload gated** → ConfigFailure, no
  `/contacts/sync` endpoint yet), `ContactSyncCubit`/`ContactSyncPage`
  (permission via M7 PermissionFlow → read → count + preview list → gated
  "Sync contacts"). Route `AppRoutes.contactSync` ('/find-friends'); entry =
  Settings ▸ "Find friends". `ApiEndpoints.contactSync` un-commented (ready to
  wire). NOT live-verified yet — emulator closed mid-session; sample contacts
  are hard to inject via the content provider (use a vCard import next time).

- **Wallet + Transactions built.** ~20 screens; analyze clean; **168 tests
  pass**. Verified live on Android. IMPORTANT API finding: **there is NO
  `/orders` endpoint** — the design's Orders/Payments-per-order flow has no
  backend (logged MISSING_APIS #9). The real money API is the **wallet**
  (app credits), which is what I built.
  * `wallet/` feature: `Wallet` entity (balance + post/boost/broadcast costs +
    razorpay_configured/demo_topup flags), `CreditPackage`, `WalletTransaction`
    (type→isCredit, reason→human label). `WalletRemoteDataSource` (GET /wallet,
    /wallet/packages, /wallet/transactions), repo, `WalletCubit` (wallet+packages,
    packages non-fatal) + `TransactionsCubit` (paginated).
  * `WalletPage` (route `/wallet`): gradient balance card, "What things cost",
    Buy-credits packages (₹ tonal buttons), transactions icon → `/transactions`.
    Profile "Wallet & credits" row now routes here.
  * `TransactionsPage` (route `/transactions`): credit(green ↙)/debit(red ↗)
    rows, running balance, +/- amounts, pagination.
  * **Buy is GATED**: `POST /wallet/checkout`+`/verify` exist but completing a
    purchase needs the **Razorpay Flutter SDK + live keys** (dev wallet reports
    razorpay_configured=false). Tapping Buy shows a clear message; wire
    `razorpay_flutter` to enable. Noted in MISSING_APIS #9 client-note.
  * Tests +8 (entity parsing incl. reason labels, WalletCubit incl.
    packages-non-fatal, TransactionsCubit paging/empty).
- **Offers feature built (Make an offer + Offers inbox).** First slice of the
  commerce flow; real APIs. analyze clean; **160 tests pass**. Verified live on
  Android end-to-end (offer button → sheet → submit → "Offer sent" → appears in
  the Received inbox).
  * `offers/` feature: `Offer` entity (normalizes received=show sender /
    sent=show load author), `OffersRemoteDataSource` (GET /offers?tag=received|
    sent paginated; POST /loads/{id}/offers = body+price), repo, `OffersListCubit`
    (Received/Sent tabs + paging) + `MakeOfferCubit` (price+remarks validation,
    409 message surfaced).
  * `MakeOfferSheet.show(context, loadId, loadTitle)` modal (price + remarks +
    Submit) → returns created Offer. `OffersPage` (route `/offers`, AppSegmented
    Received/Sent, rows: avatar, load title, remarks, ₹price, time; tap → opens
    the chat via a synthesized Conversation from conversation_id).
  * PostCard gained an optional `onOffer`; `_Actions` shows an **Offer** button
    (outline, beside Request) when `can_make_offer` — wired in feed + marketplace.
    Profile Account menu got an **Offers** row → `/offers`.
  * Tests +10 (offer parsing, list cubit tabs/paging, make-offer validation/
    success/failure).
  * NOTE: on a 409 (already offered) the API returns the existing
    conversation_id; today we just show the message — deep-linking to that chat
    on 409 is a nice follow-up (needs the ApiClient to surface the 409 body).
- **Settings + Notifications screens built.** 17 screens; analyze clean; 150
  tests pass. Verified live on Android.
  * **Settings** (`settings/presentation/pages/settings_page.dart`, route
    `/settings`): full screen replacing the old quick sheet. Appearance =
    theme selector (AppSegmented System/Light/Dark → ThemeCubit, live + persists);
    Push-notifications toggle (local pref, gated backend); Account = Edit profile
    / Change password; Support = Help / About (v1.0.0); Danger = Log out (confirm
    → AuthCubit.logout) + Delete account (gated, MISSING_APIS #8). Wired the feed
    gear, profile gear, and profile "Settings" row all to `/settings`. **Deleted
    `settings_sheet.dart`** (superseded) — no remaining refs.
  * **Notifications** (`notifications/presentation/pages/notifications_page.dart`,
    route `/notifications`): the feed bell now pushes here (was a dead snackbar).
    Honest gated "All caught up" empty state — no in-app notifications API
    (MISSING_APIS #5); row/section layout ready to drop in when it exists.
  * MISSING_APIS.md #8 added (delete account) with Purpose + alias hints.
- **Search + Marketplace built — bottom nav now 100% real (no ComingSoon).**
  15 screens built; analyze clean; **150 tests pass**. Verified live on Android.
  * **Search** (people, `search/` feature): `SearchRemoteDataSource.searchUsers`
    (GET /users?q=, reuses core User) → `SearchRepository` → `SearchCubit`
    (debounced 350ms, min 2 chars; results/empty/error; **recent searches**
    persisted as JSON in shared-prefs via `StorageKeys.recentSearches`, dedupe +
    cap 8). `SearchPage`: app-bar search field + clear, RECENT list (tap/remove/
    clear-all), RESULTS rows (avatar, bio/role, verified), tap → a peek sheet
    with a **Message** button gated ("chat-from-search" needs POST /chats, a
    later wire). Post/content search has no API text query (logged under
    MISSING_APIS "Search").
  * **Marketplace** (`marketplace/` feature): reuses **FeedCubit** with a new
    `fixedSlug` ctor param pinned to `'business'` (ignores filter chips) + the
    same `PostCard`. `MarketplacePage`: "Marketplace" appbar + New-listing (+)→
    create-post, pull-to-refresh, infinite scroll, request/report/delete.
  * Shell: `SearchPage()` + `MarketplacePage()` replace the last two ComingSoon
    tabs; `coming_soon_page.dart` no longer referenced.
  * Tests +8: search cubit (debounce guard, results/empty/error, recents
    dedupe/cap/remove/clear, cached load) and FeedCubit fixedSlug.
- **Design audit vs Lyra HTML — aligned all built screens (user-requested).**
  Compared every built screen to the design; 9/11 already matched. Applied the
  gaps (user: "update all not similar to html"). analyze clean; **142 tests
  pass**. Verified live on Android. Missing APIs logged in MISSING_APIS.md #6
  (create-post multi-image/location/tags) and #7 (profile posts count).
  * **Create Post → full "New post" redesign** (create_post_page.dart rewritten):
    X · "New post" · **Publish**; **reorderable multi-image strip** (numbered
    thumbnails + remove, dashed "Add" tile via a custom dashed-rect painter,
    "Hold & drag to reorder", pickMultiImage); title+caption card ("Write
    something…" / "Add a caption…"); Category chips; **Add location** + **Add
    tags** rows (gated "coming soon" — no API). State refactored single
    `imagePath` → ordered `imagePaths` (coverImagePath = first uploaded;
    hasExtraImages shows a "only first photo uploads" note). `onReorderItem`
    (not deprecated `onReorder`).
  * **Feed → "Suggested creators" carousel** (suggested_creators_strip.dart) as
    the feed's header row: "Coming soon" tag + placeholder cards (gradient
    avatar, skeleton bars, **disabled Follow**) — gated, no fabricated people
    (no follow/suggestions API, MISSING_APIS #4). Inserted at index 0 of the
    loaded feed ListView.
  * **Profile → "Posts" stat** now leads the strip (gated "—", no count API),
    Credits/Role kept.
  * **Chats → "Unread" filter** chip added (client-side hasUnread filter).
  * GOTCHA: a card Column in a fixed-height horizontal ListView overflowed 8px —
    bumped the strip height (avatar+bars+AppButton needs ~188).
- **Module 9 — Chat module DONE (all 3 chat types).** Verified live on Android
  (inbox, direct thread, send round-trip, composer options). Screens built: 13.
  Three chat kinds per the API + user requirement: **direct** & **group** from
  GET /chats (`type`), **broadcast** from GET /broadcasts (separate resource).
  * `Conversation` entity normalizes both endpoint shapes into one inbox row
    (fromChatJson / fromBroadcastJson); `ChatMessage` entity.
  * `ChatRemoteDataSource` spans all three: GET /chats, GET /broadcasts,
    GET /conversations|broadcasts/{id}/messages (cursor paging via before_id +
    meta.has_more/next_before_id), POST message (text OR multipart image via
    `attachments[]`), POST /conversations/{id}/read.
  * `ChatListCubit` (filter All/Direct/Groups/Broadcasts — All merges both
    endpoints newest-first) + `ConversationCubit` (load, loadMore prepends
    older, send text/image, markRead skipped for broadcasts, blocked when
    !can_chat).
  * `ChatListPage` (inbox: filter chips, rows with avatar + type badge
    [group=people, broadcast=campaign], last-message preview, time, unread
    gradient pill) → replaced the Chats ComingSoon tab. `ChatThreadPage`
    (gradient/gray bubbles aligned by sender, group sender labels, image
    bubbles, pagination on scroll-to-top).
  * **Composer matches the design** (checked the HTML): `+`(add_circle) attach
    sheet [Photo · Camera · File — Photo/Camera wired via image_picker +
    M7 PermissionFlow → multipart send; File stub], rounded field with an
    emoji(mood)/@-mention(group) affordance, and a trailing **mic ⇄ send** swap
    (send when text present; mic = "Voice messages coming soon" stub — real
    voice recording deferred, would need the `record` pkg + audio upload).
  * Route `AppRoutes.chatThread` (Conversation passed via GoRouter `extra`).
  * analyze clean; **140 tests pass** (+15 chat: model parsing, both cubits,
    filters, send text/image, pagination, canChat gating).
  * DESIGN NOTE for future: composer also specs a voice-recording state (timer
    0:14 + animated waveform) and typing-dots; bubble slide-up/fade animations.
- **Module 9 — Profile module DONE (My Profile + Edit Profile).** Verified live
  on the Android emulator vs a mock API (login → /me → profile; Save round-trip
  shows "Profile updated"). Screens built now: **11**.
  * `ProfilePage` (bottom-nav Profile tab, replaced the ComingSoon placeholder):
    header (avatar w/ creator story-ring, name + verified badge for creators,
    @handle · role, bio), stats strip (Credits / Role / Status), Edit + Share
    buttons, Account menu (Wallet/Settings/Help). Reads the live user from
    AuthCubit so edits reflect instantly.
  * `EditProfilePage` + `EditProfileCubit`: avatar picker (camera/gallery via
    M7 PermissionFlow), name/bio/phone; **diffs against the seeded user and PUTs
    only changed fields** (no-change = instant success, no API call); 422 field
    errors; on success → AuthCubit.updateUser + pop.
  * Data: `ProfileRemoteDataSource` (GET /profile, PUT-as-POST /profile,
    multipart when avatar) → `ProfileRepository` → DI singletons. Added
    `AuthRepository.cacheUser` + `AuthCubit.updateUser` to persist the edited
    user. Routes: `AppRoutes.editProfile`.
  * Reusable `SettingsSheet` (theme/change-password/logout, now with a logout
    confirm) extracted from feed_page and shared with profile. Reusable
    `MediaUrl.resolve` helper for server-relative image paths.
  * analyze clean; **125 tests pass** (+9: EditProfileCubit 7, AuthCubit
    updateUser 2).
  * GOTCHA FIXED: a bare `AppButton` inside a Row throws "BoxConstraints forces
    an infinite width" because AppButton defaults to `expanded:true`
    (width:infinity). In a Row, wrap it in Expanded OR pass `expanded:false`
    (the Share button uses expanded:false + an icon).
  * Verification harness (scratchpad, not committed): `mock_api.py` (Python
    stdlib mock on :8787) + `flutter run --dart-define=BASE_URL=http://10.0.2.2:8787`
    on emulator-5554; drive via `adb shell input tap` + `adb exec-out screencap`;
    hot reload=SIGUSR1 / hot restart=SIGUSR2 to the `flutter run` pid (a layout
    fix needed a full restart, not reload).
- **Module 9 STARTED — Create Post / composer screen DONE.** Full clean-arch
  vertical: `NewPost` entity, `FeedRemoteDataSource.createLoad` (POST /loads —
  multipart FormData when an image is attached, else JSON), repo `createLoad`
  → `Result<Load>`, `CreatePostCubit`/`CreatePostState` (loads categories via
  PostTypeRepository, title/body/category/image fields, canSubmit=title
  non-empty, submit with 422 field-error flattening, no double-submit),
  `CreatePostPage` (category chips, title+body fields, image pick via camera/
  gallery sheet through Module-7 `PermissionFlow`, AppBar "Post" action).
  Added `image_picker: ^1.1.2`. `FeedCubit.prepend` inserts the new post at the
  top; feed `+` button now pushes `/create-post` and prepends the returned
  Load. Route `AppRoutes.createPost` wired. analyze clean; **116 tests pass**
  (+11: create-post cubit paths + feed prepend). NOTE: image_picker on iOS uses
  the Info.plist camera/photos strings already added in M7. Screens built now:
  **9** (was 8). NOT yet run on a device this session — verify on Android.
- **Module 7 done — Runtime Permission Manager.** Reusable, SDK-agnostic layer
  under `lib/core/permissions/`: `AppPermission` enum (contacts/camera/photos/
  microphone/notification → permission_handler), `PermissionOutcome`
  (granted/denied/permanentlyDenied/restricted/limited + isUsable/
  requiresSettings), `PermissionGateway` seam (real `PermissionHandlerGateway`
  + fakes in tests), `PermissionManager` (status/ensure/openSettings; ensure
  never re-prompts when permanentlyDenied/restricted), `PermissionFlow` UI
  helper (ensure + "Open settings" dialog). Registered in DI. Platform config:
  Android manifest perms (READ_CONTACTS, CAMERA, RECORD_AUDIO,
  POST_NOTIFICATIONS, READ_MEDIA_IMAGES/VIDEO, capped READ_EXTERNAL_STORAGE);
  iOS Info.plist usage strings (contacts/camera/photos/microphone) + added the
  Module-6 iOS `GADApplicationIdentifier` (sample id). analyze clean; **105
  tests pass** (+12 permission tests: outcome mapping, ensure paths, settings).
- **Module 6 finalized.** Was already implemented (AdService init in main.dart,
  FeedAdSlot native→banner fallback, `_buildEntries` interleave every
  AdConfig.postsBetweenAds, ad interleave tests). This session closed the one
  loose end: `_buildEntries` now honors `AdConfig.minPostsBeforeFirstAd` (was
  dead config) and the test mirror matches.
- **iOS build attempt (2026-08-28): BLOCKED by host Xcode.** Booted iPhone 16
  Pro (iOS 18.0) sim; Flutter sees it. Build fails at xcodebuild
  `-showBuildSettings` because the generic `platform:iOS` (Any iOS Device)
  destination reports "iOS 26.2 is not installed" — this aborts ALL destination
  resolution, incl. the booted simulator. The iOS 26.2 **SDK** IS present
  (`xcodebuild -showsdks`) but the runnable **platform component** is not.
  `xcodebuild -downloadPlatform iOS` FAILS here (tries to fetch iOS 26.3.1 sim,
  network-blocked). FIX = user installs it via Xcode ▸ Settings ▸ Components ▸
  GET iOS 26.2 (GUI), or `sudo xcodebuild -runFirstLaunch` (needs password).
  NOTE: project now uses **Swift Package Manager**, not CocoaPods — there is NO
  Podfile and none is needed (plugins resolve as SPM packages). Android is fine.

- **Module 5 done.** Feed (GET /loads): Load model, paginated datasource/repo,
  FeedCubit (pagination, pull-to-refresh, All/Buy/Sell filters, request/report/
  delete), PostCard per design (verified/boosted badges, media, Request CTA,
  overflow menu), states (loading/empty/error). **Verified live vs a mock API**
  (login->/me->/loads, filters, cards). 88 tests pass.
- **App shell + bottom nav** (design): HomeShell w/ 5 tabs (Home=Feed live;
  Search/Marketplace/Chats/Profile = ComingSoon placeholders), AppBottomNav
  redesigned to icon-only + gradient active pill + chat badge. Feed AppBar now
  matches design (add_box, gradient "Lyra" wordmark, notifications, settings
  sheet w/ theme+logout+change-password).
- **Auth-extra screens BUILT + WIRED** to their (pending) endpoints per
  MISSING_APIS.md — ForgotPassword→/auth/password/forgot, Otp→/auth/otp/
  verify+send, ChangePassword→/auth/password/change. Real calls (loading +
  snackbar on error); NO dev-notice banners shipped (removed per user).
- **Assets wired**: Lyra app launcher icon (SVG->PNG via qlmanage ->
  flutter_launcher_icons, Android+iOS); 113 UI icons bundled under
  assets/icons/outline + LyraIcon(flutter_svg) helper; onboarding uses the
  REAL illustrations from handoff 3/illustrations (handoff 2's onboarding_*.png
  were mis-cropped caption text — do not use).
- **MISSING_APIS.md** written: OTP, forgot/reset/change password, follow +
  suggested creators, notifications list. Given to user to provide.
- dart-define BASE_URL support added (inject real API URL at build; also used
  with a local mock for verification). Debug manifest allows cleartext for the
  local mock only.

- Module 4 done. Full auth flow, all screens designed + API-wired:
  * Data: AuthRemoteDataSource (register/login/me/logout), AuthRepository
    (token in secure storage + user cached as JSON; best-effort logout).
  * State: AuthCubit (session bootstrap w/ cached-user + /me refresh, 401→logout,
    non-401 keeps cached), LoginCubit/RegisterCubit (submit + 422 field errors),
    Validators, AuthFormState.
  * Screens matching design: SplashPage (animated brand), OnboardingPage
    (3 slides + dots + Skip), LoginPage (Welcome back, remember-me, forgot=
    disabled since no API), RegisterPage (name/email/password/confirm).
  * Router: auth-aware redirects (splash/onboarding/login/register/feed) via
    GoRouterRefreshStream; app bootstraps session on start; 401 interceptor
    wired to AuthCubit.logout. HomePlaceholderPage = temporary authed landing.
  * **Verified on device**: onboarding, login, register screens (screenshots).
  * analyze clean; **71 tests pass** (+16: auth repo persist/failure/logout/
    cache via mocktail, AuthCubit bootstrap paths, validators, login widget
    validation + submit).
  * NOTE: OTP + Forgot/Change-password screens from the design are DEFERRED —
    the API has no endpoints for them (building would be fake completion).
  * Register omits phone/avatar (profile fields, not in register API) — added in
    the Profile module.

- Module 3 done. Shared JSON reader extension (defensive casts); shared
  models User (role helpers canPost/isCreator/isAdmin, copyWith), PostType,
  Author. ApiEnvelope decoder (unwraps {data} object + {data,meta} list).
  First clean-arch vertical slice — post_types: remote datasource → repository
  (interface in domain, impl in data via BaseRepository.guard) → registered in
  DI. This is the pattern auth/feed will follow. analyze clean; **55 tests pass**
  (+21: models incl. string-number/null/missing edge cases, envelope decoding
  incl. garbage entries, repo success/AuthFailure/ConfigFailure, ApiClient
  DioException mapping for 422 field errors + 402 + 200 via stub adapter).

- Module 2 done. Aurora Bloom light+dark theme (AppColors + LyraColors
  ThemeExtension, AppTheme, Sora + Plus Jakarta Sans via google_fonts,
  spacing/radius tokens), ThemeCubit (persisted, defaults to system). Reusable
  widgets: AppButton (gradient/tonal/outline + loading/disabled), AppTextField
  (filled, obscure toggle, error), AppSegmented + AppChip, AppAvatar (initials/
  gradient/ring), state views (Loading/Empty/Error+retry), AppBottomNav,
  AppOverlays (dialog/sheet/snackbar). ComponentGallery dev screen wired to
  splash route for verification. analyze clean; 33 tests pass (13 new theme +
  widget tests). **Verified on Android emulator in light AND dark** (screenshots
  sent). Env fixes: android-37 platform, AdMob app id + INTERNET in manifest.

- Module 1 done. Dependencies added; core architecture built:
  config (centralized configurable Base URL + copyWith), constants
  (app/endpoints/ad_config), network (ApiClient with Dio + auth/logging
  interceptors, DioException→AppException mapping, NetworkInfo, PaginationMeta),
  error model (sealed Failure + AppException), Result type, StorageManager
  (secure token + prefs), BaseRepository (AppException→Failure), logger,
  extensions, get_it DI, go_router skeleton, LyraApp boots to a placeholder.
- `flutter analyze`: no issues. `flutter test`: 19/19 pass (pagination edge
  cases, Result folding, email validation, config placeholder detection,
  repository failure mapping incl. 401/402/403/404/422/500/unknown/transport).

## Next Step
- **Module 8 — Contact Sync (payload only).** API endpoint NOT available
  (`/contacts/sync` is commented out in api_endpoints.dart). Build: read device
  contacts via flutter_contacts behind `PermissionManager`/`PermissionFlow`
  (AppPermission.contacts), normalize (dedupe, E.164-ish phone normalization),
  map to a `ContactSyncPayload` model, and a repository stub that produces the
  JSON payload and is ready to POST once the endpoint lands. Tests for
  normalization + payload shape. NO fake API calls.


## Environment fixes applied (this session)
- **android-37 platform**: only `android-37.0` (minor-versioned) was installed;
  created a hybrid `~/Library/Android/sdk/platforms/android-37` (symlinks to
  android-37.0 assets + patched source.properties ApiLevel=37) so plugins
  requiring compileSdk 37 (flutter_secure_storage, permission_handler) resolve.
  App `compileSdk = 37` set in android/app/build.gradle.kts.
- **AdMob App ID**: google_mobile_ads crashes at launch without an app id.
  Added Google's SAMPLE app id + INTERNET permission to AndroidManifest.xml.
  Replace with the real AdMob app id in Module 6. (iOS Info.plist still TODO.)

## Assumptions
- Contact-sync JSON follows the user's referenced structure (to be fetched when Module 8 starts).
- Using manual fromJson/toJson (no build_runner) to avoid codegen churn.
