# NexVault — Android app

Flutter app (Android) on Supabase.

## What's in it

| Tab / screen | What it does |
|---|---|
| First launch | Guest account created automatically; Terms & Privacy consent dialog |
| **Explore** (opens first) | Posts from every channel the user may see, 3-column grid; All / Latest / Popular / Most watched |
| Post | Items with 👑 premium badge; **Watch / View** → login → plan (premium) → online player |
| **Channels** | Search, Discover / Joined, Trending / Latest / Top Rated, Join (needs login), **Create** a channel |
| Channel page | Telegram-style posts with date chips, folders, share; Join bar; creator's **+** to post videos/images |
| **Feed** | Posts from joined channels |
| **Cloud** | Personal storage for premium users: upload, folders, view images/videos, rename, delete, storage meter |
| **Profile** tab | Premium plans (Trial … Diamond); **Next** sends a plan request (payments come later) |
| Profile (person icon) | Name edit, account, My Channels (created + joined, with approval status), Add Channel |
| Settings | Policies, Logout, Delete account |

What each user sees is decided by the database (audience, premium, approvals).

## Two APKs from the same code

| File | Install source recorded |
|---|---|
| `NexVault.apk` | organic (`direct`) |
| `NexVault-ads.apk` | Meta ads (`utm_source=meta…`, via `--dart-define=APK_REFERRER=…`) |

Same package name (`com.nexvault.app`) and the same signing key, so either one
updates the other. The key in `android/app/tester-release.jks` is for **testing only**.

GitHub Actions (`.github/workflows/mobile.yml`) builds both on every push and
uploads them as the **NexVault-apks** artifact on the workflow run.

## Build locally

```bash
flutter pub get
flutter build apk --release                                   # organic
flutter build apk --release \
  --dart-define=APK_REFERRER="utm_source=meta&utm_medium=paid_social&utm_campaign=apk_download"   # ads
```

Point at another Supabase project with
`--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_KEY=sb_publishable_…`.

## Supabase settings the app needs

- Authentication → **Allow anonymous sign-ins**: ON (guest accounts)
- Authentication → Email: ON. For instant account creation in testing, turn
  **Confirm email** OFF; otherwise users must click the email link first.
