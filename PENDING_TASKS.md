# Pending tasks (tracking — do not lose)

Kept so nothing is missed. Update status as each is done. Design doc: `/Users/charmi/Downloads/Lyra.dc.html`. API docs: https://nexveero.com/api-docs.html

## Chat
- [x] **1. Ask/question chat → "View post"** — DONE: `Conversation.loadId` + `FeedRepository.getLoad(id)` + a "View post" icon in the chat thread AppBar (shown when `loadId != null`) → opens post detail.
- [x] **4. Read receipts on API load** — DONE: `getPeerLastRead(id)` → GET /conversations/{id} `peer_last_read_at`, seeded in `load()` (1:1 only) so ✓✓ shows immediately.
- [x] **5. Labels** — KEEP AS-IS per user ("chat ma jem che tem j"): assign via long-press → Labels; manage page; filter bar. (Web assigns via a header tag-icon; user chose to keep long-press.) Optional-not-doing: inline filter row + "+Label" chip.
- [ ] ~~5. Labels detail~~ API (kept for reference):
      - `POST /chat-labels` `{name (max60, unique), color (hex), sort_order (0-9999)}` → 201
      - `PUT|PATCH /chat-labels/{id}` (update), `DELETE /chat-labels/{id}` (204)
      - `POST|DELETE /conversations/{id}/labels/{labelId}` — attach/detach; returns conversation with `labels[]`
      - Filter inbox: `GET /chats?label_id=1`
      - Check WhatsApp for the UX (label chips on chats, manage labels, filter by label).
- [ ] **6. Group members → tap a member → their Business profile** (member row tap opens business profile). Also (see #2) any user-name tap → business profile.

## Profiles — TWO SEPARATE FLOWS (user emphasised: "user profile n business profile alag che, html ma banne no alag flow che")
Design has two distinct profile screens, each with own + other-user variants:
- **Business Profile** (HTML ~688–790, "Business Profile · Verified / Premium Customer"): gradient cover + rounded-square avatar with verified/premium ribbon + Name + **verified** (+ premium `workspace_premium`) + chips **Verified · Business · Premium Customer** + `@username` + bio + stat cards **Posts | Offers** + **Go Premium** card (Unlock Premium Customer badge) OR **Premium active · Renews {date} · Manage** + **Edit profile** (gradient) + **Share**. Other-user variant swaps Edit/Premium → **Chat + Share**, adds ⋯.
- **Creator/User Profile** (HTML ~2765+, "My Profile / Creator Profile · other user"): avatar + Name + verified + `@username · Creator` + bio + single **{N} Posts** + (own) **Edit profile + share** / (other) **chat_bubble Chat + share**.
- DATA: `GET /users/{id}` public shape = id, name, username, share_url, deep_link, avatar_url, bio, **is_verified**, **is_premium**, posts_count, last_seen_at. **No roles, no business_name, no offers_count** for other users. So on OTHER users: Business chip + Offers stat can't be shown (data absent) — only own profile (from /auth/me + /profile) has business_name etc. Added `User.isVerified/isPremium/isBusiness`.
- [x] **A. Business Profile screen (own)** — DONE: `profile_page.dart` redesigned ditto (gradient/amber cover + settings gear, rounded-square ribbon avatar, name+verified+premium, Verified/Business/Premium chips, @handle·role, bio, Posts stat, Go Premium / Premium active card, Edit profile + Share). Offers omitted (no API — single Posts stat, no faked number). Account/admin menu kept.
- [x] **B. Other-user profile** — DONE: `user_profile_page.dart` ditto (avatar ring, name+verified+premium, @username, bio, Posts, **Chat** + **Share** + ⋯ Share profile/Copy link). No Business chip/Offers/role (API omits them for others).
- [x] **2/3/6 taps** — DONE: #2 post author name/avatar tap (feed + business cards) → userProfile; #3 contact-info **View business** → userProfile(peerId); #6 group member row tap → userProfile(member id).

## Blocking (API finding)
- **Admin can't be blocked** = SERVER-ENFORCED only. `GET /users/{id}` does NOT return `roles`, so the client can't know a peer is admin → can't pre-hide Block. Current behaviour is correct: block attempt → server returns the error message → contact_info already surfaces it. No client change needed (documented per user request).

## Feed / Profile / Business
- [ ] **2. Post author name tap → Business details/profile** (design "Business Feed · Business profile"). Tapping the post's user name opens their business profile.
- [ ] **3. "View business" button in chat detail / contact info** → opens the peer's business profile screen.
- [x] **7. Profile `posts_count`** — DONE: added `User.postsCount` (from `posts_count`); profile "Posts" stat now shows the real count (was "—").

## Done
- [x] **8. Google Maps / location** — key wired (manifest/plist/AppDelegate/config), location picker + static-map bubble + in-app map viewer. Needs Maps SDK + Places + Static Maps + billing ON in Google Cloud to render live.
- [x] Broadcast message overage dialog (Debit & send / limit over).

## Deferred (blocked)
- [ ] **Resume ditto-audit** of all screens vs `Lyra.dc.html` + produce an "EXTRAS in app (not in design)" list. 4 agents failed on the session rate limit (resets ~9:30pm IST 2026-09-26) — re-run after reset. Scope split: (a) auth/shell/notifications/contacts, (b) feed/business/search/profile, (c) orders/offers/groups/subscription, (d) admin/settings/security/tags, plus wallet + broadcasts pages.
- Backend/config (user side): OneSignal App ID, backend push send + `notification` event, AdMob real unit IDs, push provider decision (OneSignal vs FCM), paid Apple Developer (App Store + APNs), Maps key restriction.
