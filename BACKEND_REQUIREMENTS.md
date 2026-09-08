# Nexveero — What We Need From Backend

Gaps between the **design** (`Lyra.dc.html` + `Chat App (3).pdf` flow) and the
**current API** (`api-docs.html`, base `/api/v1`, 176 endpoints). Each item is a
screen/behaviour the design specifies that has **no endpoint yet** (or an
endpoint too small to cover it). This is the authoritative "v2 / Nexveero" list;
it supersedes the older `MISSING_APIS.md`.

**How to read each item:** _Design_ = what the design/PDF shows · _API today_ =
what exists now · _Needed_ = the endpoint(s)/fields we need · _Check existing_ =
likely alternate names to look for before building new (if it already exists
under another path, just tell us the path — we re-point one line, no screen
changes).

**Conventions (match existing API):** `Authorization: Bearer {token}`,
`Accept: application/json`, success bodies wrapped in `{ "data": ... }`,
validation errors as `422 { "message", "errors": { field: [..] } }`,
list endpoints paginated (`?page`, `?per_page`, `meta`).

Legend: 🔴 blocks a built screen · 🟠 needed for an upcoming module · 🟢 nice-to-have.

---

## A. Auth & Onboarding

### A1. 🔴 Multi-identifier login (username / mobile / email)
- **Design:** login accepts **username, mobile, or email** + password.
- **API today:** `POST /auth/login` accepts **email only** ("Account email to look up").
- **Needed:** accept a single `login`/`identifier` field resolving to email **or**
  phone **or** username, e.g. `POST /auth/login { "identifier": "...", "password": "..." }`.
- **Check existing:** does `email` already accept a phone/username? a `username` column?

### A2. 🔴 OTP — email + mobile verification
- **Design / PDF:** Register → **Email OTP** → **Mobile OTP** before the account
  is submitted. (We currently plan to run these on **Firebase** on the client;
  this item is only needed if you want OTP verified/enforced **server-side**.)
- **API today:** no OTP endpoint of any kind.
- **Needed (only if server-side):**
  - `POST /auth/otp/send` → `{ "identifier": "email-or-phone", "channel": "email|sms" }`
  - `POST /auth/otp/verify` → `{ "identifier": "...", "code": "123456" }`
  - Or: accept Firebase ID tokens on `POST /auth/register` (`email_verified`,
    `phone_verified` flags / `firebase_id_token`) so the server trusts client OTP.
- **Check existing:** `verify`, `otp`, `code`, `2fa`, `email/verify`, `phone/verify`, `activation`.
- **Decision needed from you:** OTP via **Firebase (client)** or **backend**?

### A3. 🟠 Forgot / reset / change password
- **Design:** "Forgot password?" → send reset code → set new password; Settings → change password.
- **API today:** none.
- **Needed:**
  - `POST /auth/password/forgot { "email" }`
  - `POST /auth/password/reset { "email", "code", "password", "password_confirmation" }`
  - `POST /auth/password/change { "current_password", "password", "password_confirmation" }` (auth)
- **Check existing:** Laravel defaults `/forgot-password`, `/reset-password`, `password/email`.

---

## B. Business Profile (KYC / verified / premium)

### B1. 🔴 Full business-details form (~18 fields)
- **Design / PDF:** after approval, "Fill Business Details" — address, **products**,
  **company type**, **MSME** no., **logo**, **social links**, **description (≤1020)**,
  **association**, **tags (5–10)**, website, etc. (~18 fields).
- **API today:** `POST /profile` accepts **only** `name`, `bio`, `phone`, `avatar`.
- **Needed:** extend `POST /profile` (or a new `POST /profile/business`) to accept:
  `business_name`, `company_type`, `msme_number`, `logo` (file), `website`,
  `description` (≤1020), `association`, `address`, `city`, `state`, `pincode`,
  `products[]`, `tag_ids[]` (5–10, from `/tags`), `social_links` (object:
  instagram/facebook/linkedin/youtube/x). Return them all on `GET /profile`.
- **Check existing:** any `business`, `company`, `kyc`, `onboarding/details` route.

### B2. 🟠 Verified / Premium badges
- **Design:** profile shows **Verified badge** (after admin approval) and
  **Premium badge** (with active subscription).
- **API today:** `approval_status` exists; `subscription` object exists. No explicit
  `is_verified` / badge field.
- **Needed:** `is_verified` (bool) + a badge/tier on the user (or derive:
  verified = `approval_status==approved`, premium = `subscription.status==active`).
  Confirm the intended rule so the UI shows the right badge.

---

## C. View Business tab (business directory)

### C1. 🟠 Business showcase feed + search by product/tag
- **Design:** "View Business" tab — business cards (images/short videos), search
  by **products** and **tags**, **boost business**.
- **API today:** `GET /users` is a name/phone directory only; `GET /loads` is the
  post feed; `boost` exists for loads.
- **Needed:** `GET /businesses?search=&tag_id=&product=&page=` returning business
  profiles (logo, name, verified, products, tags, media) + `POST /businesses/{id}/boost`
  (or reuse a boost endpoint). Confirm if "boost business" bills wallet credits.
- **Check existing:** `businesses`, `directory`, `vendors`, `shops`, `catalog`.

---

## D. Status tab (24h stories)

### D1. 🔴 Stories CRUD + view tracking
- **Design / PDF:** "Status" tab — **24h** stories, **contacts-only** visibility, ads interleaved.
- **API today:** nothing (`/status`, `/stories` absent).
- **Needed:**
  - `GET /stories` — contacts' active (unexpired) stories, grouped by user.
  - `POST /stories` — multipart (image/video, ≤15s), auto-expire 24h.
  - `POST /stories/{id}/view` — mark seen (for seen/unseen rings + view count).
  - `GET /stories/{id}/viewers` — who viewed (own stories).
  - `DELETE /stories/{id}`.
- **Check existing:** `stories`, `status`, `moments`, `reels`.

---

## E. Feed / Posts (Loads)

### E1. 🟠 Multi-image (carousel) + video posts
- **Design:** post types **carousel**, **video**, **video+text**; **mark as sold /
  deal closed**; **inactivate** (+ 7-day auto-inactive).
- **API today:** `POST /loads` — confirm it accepts **multiple media** and **video**
  (doc mentions `media`, `video` but a single-image create is what we wired).
- **Needed:** confirm `POST /loads` accepts `media[]` (multiple files + video) and a
  `post_type`; plus `POST /loads/{id}/sold` (mark sold) and `PATCH /loads/{id}`
  `status=active|inactive`. If auto-inactive after 7 days is server-side, confirm.
- **Check existing:** `media[]`, `attachments[]`, `loads/{id}/close`, `mark-sold`, `status`.

---

## F. Search

### F1. 🟢 Suggested businesses / people
- **Design:** Search shows a **SUGGESTED** section.
- **API today:** no `suggested` endpoint.
- **Needed:** `GET /search/suggested` (or `GET /businesses/suggested`).
- **Check existing:** `suggested`, `recommended` (note: `/groups/recommended` exists — is there a users/business equivalent?).

---

## G. Notifications

### G1. 🔴 Notifications list
- **Design:** Notifications screen (offers, approvals, chat, system).
- **API today:** only per-feature unread counts (`/offers/unread-count`,
  `/chats/unread-count`, `/questions/unread-count`); **no notifications feed**.
- **Needed:** `GET /notifications?page=` + `POST /notifications/{id}/read` +
  `POST /notifications/read-all` + `GET /notifications/unread-count`.
- **Check existing:** `notifications`, `activity`, `inbox`, `alerts`.

---

## H. Orders & Payment

### H1. 🔴 Orders (per-order transactions)
- **Design:** Orders list, order detail, per-order payment, order status in chat.
- **API today:** **no `/orders`** — only wallet credits (`/wallet`, `/transactions`).
- **Needed:** `GET /orders`, `GET /orders/{id}`, `POST /orders`
  (from a load/offer), `PATCH /orders/{id}` (status). Confirm the order model
  (buyer/seller/amount/status) or confirm the app is **wallet-credits only** and
  the design's Orders flow is dropped.
- **Check existing:** `orders`, `bookings`, `deals`, `purchases`.

### H2. 🟠 UPI payment + refund states
- **Design:** Payment adds **UPI**, plus **refund** (requested/completed), retry, change-method.
- **API today:** wallet top-up via Razorpay (`/wallet/verify`, `/wallet/demo-topup`);
  no UPI-specific flow, no refund.
- **Needed:** confirm Razorpay covers UPI (usually yes — then just a UI method), and
  add `POST /wallet/refund` / `GET /refunds` (or order-level refund) if refunds are real.
- **Check existing:** `refund`, `payment/upi`, Razorpay UPI intent flow.

---

## I. Account & Settings

### I1. 🟠 Delete account
- **Design / PDF:** Settings → delete account.
- **API today:** none (`/account`, `delete-account` absent; `DELETE /auth/login`
  only revokes the current token).
- **Needed:** `DELETE /account` (soft-delete + data handling per policy).
- **Check existing:** `account`, `users/me`, `profile` DELETE.

### I2. 🟢 Online / last-seen visibility toggle
- **Design / PDF:** toggle to hide online/last-seen.
- **API today:** `GET /presence/{id}` (read) exists; no privacy toggle.
- **Needed:** a profile setting `show_last_seen` (bool) on `POST /profile`.

---

## J. Chat (for the upcoming chat expansion — reference)
Most chat features **are** backed (labels, questions/inquiry, PIN requirement,
groups + join-requests, broadcasts). Confirm these design bits when we build chat:
- **Edit message (≤1h) / delete message (≤24h):** need `PATCH`/`DELETE /conversations/{id}/messages/{msgId}` (confirm they exist).
- **Star / pin conversation:** confirm endpoints (`.../star`, `.../pin`).
- **Attachments:** document/audio/location/contact share — confirm `POST /conversations/{id}/messages` accepts these `type`s + files.
- **Block / unblock user:** confirm `POST /users/{id}/block` exists.

---

_Last updated 2026-09-05 (post Nexveero rename + auth B2B rework)._
