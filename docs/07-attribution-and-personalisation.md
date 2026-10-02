# Install Attribution & Source-Based Channels

Product owner's requirement: when uploading content in the admin panel, choose who
sees it: **everyone**, **organic users only**, or **ads users only** (users who
installed from your Meta ads). This applies to channels and posts, and the posts
show up in Explore and Feed only for the right users. This doc adapts the owner's attribution prompt to our app's model
(Channels → Folders → Posts, guest-first accounts, tester APK distribution).

## 1. Rule

Personalisation is based **only on how the user was acquired** (ad vs organic).
No reviewer/bot detection and no cloaking. Everyone acquired the same way gets the
same experience.

## 2. Mapping the prompt to our app

| Prompt term | Our app |
|---|---|
| Content item with `SPECIAL_TAG` (`ADS_SPECIAL`) | **`audience` field** on channels and posts: `all` / `organic` / `ads` (three-way, not just a tag) |
| Catalog | Channels → Discover list, **Explore** grid, Feed |
| `episodes_for_install` | Posts of a channel (`posts_for_install`) |
| Trailer | **Preview clip** (first ~15–30 s) made by the video worker for each premium video |
| Full content | Full video in the online player (needs login + plan) |
| Admin toggles special tag | Admin panel: "Who can see this" selector on each channel and post |
| Payments snapshot | Built later, when payments are added (deferred) |

Who sees what:

| | Organic install | Ads (Meta) install |
|---|---|---|
| Audience **Everyone** | ✅ | ✅ |
| Audience **Organic only** | ✅ | ❌ |
| Audience **Ads only** | ❌ | ✅ |
| Preview clip without login | ❌ (login + plan) | ✅ |
| Full video (👑 premium) | Login + plan | Login + plan |

Premium (👑) and audience are **independent**: e.g. a premium post for organic users
only, or a free post for ads users only.

### Admin approval for organic buyers

An organic user **never** sees "Ads only" content on their own, even after buying a plan.

1. An organic user buys a plan (for now: premium granted in the admin panel; later:
   a real payment).
2. The user is automatically **highlighted** in the admin panel as
   **"Waiting for approval"** (badge + list).
3. The owner/admin reviews and clicks **Approve** or **Reject**.
4. **Approved** → the user also sees all "Ads only" content (in Channels, Explore,
   Feed), exactly like an ads user. The app refreshes automatically.
   **Rejected / no decision** → nothing changes; they keep seeing Everyone +
   Organic content.
5. The admin can **revoke** an approval at any time, or approve any user manually.

| User | Everyone | Organic only | Ads only |
|---|---|---|---|
| Ads user | ✅ | ❌ | ✅ |
| Organic user | ✅ | ✅ | ❌ |
| Organic + plan, **waiting / rejected** | ✅ | ✅ | ❌ |
| Organic + plan, **approved** | ✅ | ✅ | ✅ |

Notes:
- The user is not told they are waiting for approval (nothing in the app changes
  until approval). _Assumption, see open question 31._
- Approval belongs to the **user**, not the plan, so it stays if the plan expires
  (they still need an active plan to *play* premium content). _See open question 30._

## 3. Key simplification: guest-first accounts

The prompt has separate "before sign-in (install-based)" and "after sign-in
(user-based)" paths. In our app **every install gets a guest account immediately**,
and login upgrades that same account in place. So:

1. On first launch: create the install record → create the guest account → link
   them (`first_user_id`, first-touch attribution set **at guest creation**).
2. All content rules use **one check**, `is_ads_user()`, for guests and logged-in users alike.
3. `install_id` functions (`catalog_for_install`, etc.) are kept only as a fallback
   for the moment before the guest account exists.

Edge case to decide: an **ads guest logs into an existing organic account** (e.g.
reinstalled via the ad, then signed in with the old Google account). First touch is
immutable, so the account stays **organic** and the special channels disappear after
login. Recommended: keep the rule (first touch wins). Open question 25.

## 4. Detecting the install source (client)

**A. Direct APK (our main path, tester APK distribution)**
- Build **two APKs from the same code** (same package name, same signing key, so
  either can update the other):
  - `CloudStorage.apk`: organic, no referrer
  - `CloudStorage-ads.apk`: built with
    `--dart-define=APK_REFERRER=utm_source=meta&utm_medium=paid_social&utm_campaign=apk_download`
    (Flutter equivalent of `BuildConfig.APK_REFERRER`)
- If `APK_REFERRER` is non-empty, it is used as the referrer.

**B. Play Store (future)**
- Read the Google Play Install Referrer once per install (timeout + a few retries,
  cache the final answer). Ad links point to the Play listing with
  `&referrer=utm_source=meta&utm_medium=paid_social&utm_campaign=<name>`.
- Never upload the `-ads` build to the Play Store.

**Both**
- Random `install_id` (UUID v4) saved locally. No device ID or advertising ID.
- `record_install(install_id, referrer_status, referrer, click_ts, install_ts)` sent
  once on first start, retried until it succeeds; the returned `source` is cached
  for UI only.

## 5. Server

### Tables
```
installs          install_id PK, referrer_status, raw_referrer, source,
                  utm_source, utm_medium, utm_campaign, utm_content, utm_term,
                  click_ts, install_ts, first_user_id, created_at, updated_at
                  -- first successful read wins, never overwritten
user_attribution  user_id PK,
                  first_touch_source/medium/campaign/content/at/install_id  (IMMUTABLE),
                  last_touch_source/medium/campaign/content/at/install_id
analytics_events  id, install_id, user_id, event, content_id, created_at
                  -- events: app_open, login, content_view, preview_view,
                  --         special_content_view (deduplicated per view), purchase (later)
channels.audience, posts.audience   -- 'all' | 'organic' | 'ads'
payments.attr_source, payments.attr_campaign   -- snapshot trigger, when payments exist
```

### Referrer parsing
- `meta` when `utm_source` ∈ {meta, facebook, fb, instagram, ig, messenger, threads,
  audience_network}, or the referrer is facebook.com / instagram.com.
- `organic` for store-organic installs; `direct` for the plain APK; `other` /
  `unknown` otherwise.

### Functions
- `record_install(...)`: insert-or-ignore; returns the parsed source.
- `attribute_user(install_id)`: called at guest creation and at every login; sets
  first touch once and updates last touch.
- `is_ads_user()` / `user_source()`: security definer; `ads` if the current user's
  first-touch source is `meta`, else `organic`.
- `has_ads_access()`: security definer; true if `user_source() = 'ads'` **or** the
  user's `ads_access_status = 'approved'`.
- `is_ads_install(install_id)`: server-only (not callable by clients).
- `log_event(...)`.

### Content rules (enforced in the database, not only in the app)
- Channel / post / Explore read rules: `all` → everyone; `organic` → organic users
  (incl. approved organic users); `ads` → `has_ads_access()`. Admins see everything. Hidden, draft, and premium
  rules stay unchanged.
- Media access (signed stream URL): same rule.
- **Preview endpoint** `preview-url {post_item_id}`: checks the user/install is
  `meta` and the post is published and not hidden, then returns a short-lived
  signed URL for the **preview clip only**. Service keys stay on the server.
- Full video: always login + active plan.

## 6. App behaviour

- **Ads guest:** sees `all` + `ads` content in Discover, Explore, and Feed;
  "Watch preview" works without login; ▶ Play → login → plans page.
- **Organic guest:** sees `all` + `organic` content; ▶ Play → login → plans page.
- **Logged in:** same split, based on the account's first touch.
- When `record_install` comes back as `meta`, refresh Channels / Explore / Feed so the
  special content appears without a restart.
- Wait for the saved session to load before showing content (no flicker).
- Optional: a "For you" / special row at the top of Explore for ads users.

## 7. Admin panel

- Channel and post editors: audience selector (Everyone / Organic only / Ads only).
  Full spec in [08-admin-panel.md](08-admin-panel.md).
- Attribution report: installs, registrations (guest → logged in), plan buyers,
  purchases, revenue, **by source and by campaign**.
- Users list with source / campaign / first & last touch; user detail with plan
  and payment history (payment parts once payments exist).

## 8. Distribution (direct APK)

- CI (GitHub Actions) builds both APKs on every push to the main branch.
- APKs are published at **fixed URLs that always serve the latest build**.
  ⚠️ The GitHub repo is **private**, so its Releases are not publicly downloadable.
  Options: (a) a separate public "releases" repo, (b) a public Cloudflare R2 bucket
  (recommended, since we use R2 anyway), (c) make the repo public.
- Download page (`download.html`, hosted on Cloudflare Pages):
  - Big "Download for Android" button + install steps ("allow unknown apps").
  - "Open in Chrome" helper for the Facebook/Instagram in-app browsers (they block
    APK downloads); uses an Android `intent://` link.
  - `download.html` → `CloudStorage.apk` (organic)
  - `download.html?src=meta` or `?utm_source=meta…` → `CloudStorage-ads.apk`

## 9. Honest limits (must be understood)

- **Anyone who opens the ads link gets the ads build.** The APK can also be shared
  person to person. Special content is "campaign content", **not secret content**.
- The server cannot verify the referrer: it trusts what the app sends. A technical
  user could fake `utm_source=meta`. Fine for campaign content; not a security boundary.
- First touch never changes, so reinstalling through a different link doesn't switch groups.
- Practical: Meta's ad review may reject ads that link to APK downloads outside an
  app store. Test a campaign early.

## 10. Tests to run (once built)

1. Ads guest sees `ads` content and not `organic` content; organic guest sees the opposite; both see `all`.
2. Ads guest plays a preview without login; full video asks for login + plan.
3. Organic install cannot get a preview URL.
4. Logged-in ads / organic users see the same split as their guest selves.
5. Hidden/draft items never appear; direct DB queries from the app still follow the rules.
6. First touch stays the same after reinstall/update through the other APK.
7. Admin report counts installs / registrations / purchases / revenue per source and campaign.
