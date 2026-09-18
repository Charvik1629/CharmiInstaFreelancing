# Open Questions & Decisions

Pending decisions for the Nexveero app. Add your answer under each item's **Answer:** line and I'll act on it.

---

## Product / UI decisions (need your call)

### Q1. Location tagging on "New post"
Tapping **Add location** shows a toast *"Location tagging arrives with an upcoming update."* It's gated because (a) `POST /loads` has **no location field** on the backend, and (b) there's no GPS/place-picker plugin in the app. So a picker would capture something with nowhere to save it.
- **Options:** (a) build the UI now (a typed location field) ready to light up once the backend field exists, or (b) leave the honest toast until the backend supports it.
- **My recommendation:** leave it gated until the API field exists, so we don't ship a control that quietly does nothing.
- **Answer:**

### Q2. Two text fields on "New post" (Title + Caption)
The screen has **"Write something…"** (= `title`, **required**) and **"Add a caption…"** (= `body`, optional). This causes confusion: if you type only in the caption, **Publish stays greyed** because the title is empty.
- **Options:** (a) keep both, but make the required **Title** obvious, or (b) merge into **one** "Write something…" box (Instagram-style) sent as the title, dropping the separate caption.
- **My recommendation:** keep two for a marketplace (headline + details), but make the required title clear — unless you prefer the simpler single box.
- **Answer:** Single box. Removed the "Add a caption…" field; only "Write something…" remains (sent as the title, max 255, multi-line). ✅ done.

### Q3. Android push notifications (currently OFF)
Firebase push is **disabled on the Android build** because the project's very new Android toolchain (AGP 9.1.0 + Flutter built-in Kotlin) can't build `firebase_core`. To make Android build at all, we dropped to **AGP 8.11.1 + Gradle 8.14.4 + compileSdk 36 + JDK 17**. iOS push wiring is intact.
- **Options:** (a) keep push OFF on Android for now (everything else works), and re-enable once Firebase supports AGP 9; or (b) I re-add Firebase on the stable AGP-8.11 stack and re-test the Android build.
- **My recommendation:** keep OFF for now; revisit push once we're past the build-only phase.
- **Answer:**

### Q4. Commit the Android build fixes?
This session changed Android build config (AGP/Gradle/compileSdk, `MainActivity` moved to `com.nexveero.app`), added HTTP logging, changed all field hints to "Enter …", and **temporarily disabled Firebase**. These aren't committed yet.
- **Question:** commit + push these now (so the working Android build is saved), accepting that it also commits the temporary Firebase-disable?
- **Answer:**

---

## Backend status (reviewed 2026-09-15)

### A. Removed from the app (no API + product decision)
- [x] **Follow / unfollow** — no endpoint, and we won't build follow. Profile **Follow** button **removed**.
- [x] **Suggested creators** — no endpoint; "who to follow" feed strip **removed** (file deleted).
- [x] **Post / content search** — backend only searches **people** (`GET /users?q=`), so the Search screen is people-only by design. No post/content search UI (correct as-is).

### B. Backend HAS these (docs updated) — now just APP work, NOT blocked
- [x] **Orders: list / detail / pay / status** — `GET /orders`, `GET /orders/{id}`, `POST /orders/{id}/pay`, `PATCH /orders/{id}`. → implement in app (queued).
- [x] **Star message / Pin chat** — `.../messages/{id}/star`, `GET /messages/starred`, `.../pin`. → implement in app.
- [x] **IAP verify** — `POST /wallet/iap/verify`. → confirm app payload matches.
- [x] **Start DM with a user** — `POST /chats {user_id, pin?}`; profile **Message** wired to it.
- [x] **Groups** (the "broadcast groups" idea, and more) — full `/groups` module now exists: `GET /groups/recommended`, `POST /groups`, `GET/PUT /groups/{id}`, `GET/POST /groups/{id}/members`, join-requests approve/decline, leave. → decide how much of this to build in the app.
- [x] **Broadcast free-limit settings** — lives under `GET/PUT /admin/wallet/settings` (Wallet & credits section). → wire the admin "Broadcast limits" screen to it.

### C. Still MISSING from backend
- [ ] **Post location field** — `POST /loads` has no location field (fields: title, body, post_type_id, tag_ids, media). Needed for "Add location" on New post (Q1).

### D. Newly resolved
- [x] **Multi-image posts** — `POST /loads` now accepts a `media[]` carousel (max 10, ≤50MB each; jpg/png/webp/pdf/mp4/mov/webm). App now uploads all selected media as `media[]`.
- [x] **Profile share link** — user object now returns `share_url`/`deep_link`. Parsed into `User`; profile **Share** copies the link. (Native OS share sheet still needs the `share_plus` plugin — optional.)

## Design decisions
- [ ] **Stories / Status screen** — the `/stories` API exists, but there's **no Stories screen in the design** and "Status" was dropped from the nav. Decide whether to add a Stories screen to the design before we build it.

---

_Last updated: 2026-09-14_
