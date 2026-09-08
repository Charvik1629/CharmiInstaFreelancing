# Lyra — Module Plan

App: **Lyra** — an original social feed + messaging app (design source: "freelancing final design.html").
API: Post API `/api/v1` (source: "api-docs (1).html"). NOTE: the design's **posts/feed** map to the API's **loads** resource.

Roles: `user` (browse, request, chat, groups — no posting), `creator` (+ posts, orders, payments), `admin` (+ manage users, official groups).

## Module Breakdown
1. **Project setup & architecture** — folders, dependencies, centralized configurable Base URL, constants, DI, router skeleton, logger, storage, error model. *(compiles, runnable)*
2. **Theme & common components** — Aurora Bloom design tokens (light+dark), typography (Sora/Plus Jakarta Sans), reusable widgets (buttons, inputs, chips, states, bottom nav, dialogs/sheets).
3. **API / network layer** — Dio client, interceptors (auth/logging/error), ApiResponse, pagination meta, models for shared entities.
4. **Auth & onboarding** — Splash → Onboarding → Login/Register (+ /auth/me, logout, token storage, auth state).
5. **Feed / Post Listing (loads)** — GET /loads with pagination, pull-to-refresh, loading/empty/error states, post card, All/Buy/Sell filters, listing actions (Ask/Share/Offer/Report/Request).
6. **Google Ads** — Google Mobile Ads injected every N (configurable) posts in the feed, failure-tolerant, reusable.
7. **Runtime Permission Manager** — reusable manager (granted/denied/permanently-denied/settings), Android+iOS config.
8. **Contact Sync** — device contacts → normalize → model → JSON payload (structure per user's reference), repository stub ready for future API.
9. **Remaining screens** — Profile, Search, Notifications, Settings, Chat/messages, Groups, Wallet/credits, Offers, Broadcasts, Order & Payment, Admin.
10. **Integration & testing** — wire modules, widget/unit tests, edge cases.
11. **Final cleanup / refactor**.

## Key architectural decisions
- Clean Architecture per feature: `data` (models, datasources, repositories impl) / `domain` (entities, repositories, usecases) / `presentation` (cubit, pages, widgets). Kept lean — no boilerplate abstractions where a direct call suffices.
- **Base URL is centralized** in `core/config/app_config.dart` and NOT yet known → placeholder, single point of change.
- State management: **flutter_bloc (Cubit)** — testable, minimal.
- DI: **get_it**. Routing: **go_router**. HTTP: **dio**. Secure token: **flutter_secure_storage**.
- Ad frequency is a single centralized constant (`AdConfig.postsBetweenAds`).
- Contact-sync JSON generation is fully independent of the (unavailable) API.
- Tests accompany each module under `test/`.
