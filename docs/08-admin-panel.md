# Admin Panel

An online web panel (Next.js, hosted on Vercel or Cloudflare Pages) where the app
owner and invited admins log in, upload content, and control who sees it.
Content published here appears in the app right away.

## 1. Roles

| Role | Who | Can do |
|---|---|---|
| **Owner** | You | Everything below + invite/remove admins, edit plans, grant premium, see reports |
| **Content admin** | People you invite for a specific job | Create/edit channels, folders, and posts; upload media. Can be limited to **selected channels** only. Cannot manage admins, plans, users, or approvals |

- Login: email + password (or magic link) via Supabase Auth; optional 2-step verification.
- Owner invites an admin by email → they set a password → they get the panel.
- Every admin action is recorded in an activity log (who, what, when).

## 2. Screens

### Dashboard
- Today / 7 days / 30 days: installs (ads vs organic), new guests, logins, premium
  users, top posts, top channels.
- 🔴 **"Waiting for approval" badge** with the number of organic buyers to review.

### Approvals (organic buyers)
- Highlighted list of **organic users who bought a plan** and are waiting for a decision.
- Columns: name, email, source (organic), plan, purchase date, joined date.
- Actions: **Approve** (they can now see "Ads only" content) · **Reject** · later **Revoke**.
- Tabs: Waiting · Approved · Rejected. Every decision is logged (who, when).
- The owner can also approve any user manually from the user detail page.

### Channel requests
- App users create channels from the app; each arrives here as a request (badge on
  Channels and a banner on the dashboard).
- Owner picks **who can see it** (Everyone / Organic only / Ads only) and clicks
  **Approve**, or **Reject**. Approved channels appear in the app right away and the
  creator can start posting videos/images to them.
- Creator posts follow the channel's audience; their items are 👑 premium by default
  and only admins can change that.

### Channels
- List with search and filters (audience, status).
- Create / edit: name, handle, icon, description, category, **Audience**, status
  (draft / published / hidden).
- Folders inside a channel: add, rename, reorder.

### Upload content (main screen)
1. Choose **channel** and **folder**.
2. Drag and drop videos/images (many at once). Upload progress per file; resumes if
   the connection drops.
3. Title, caption (emoji + hashtags), optional custom thumbnail.
4. **Premium**: toggle per item (👑 = needs login + plan to play).
5. **Who can see this post** (audience):

   | Option | Who sees it in Channels, Explore, Feed |
   |---|---|
   | Everyone | All users |
   | **Organic users only** | Users who installed without your ads |
   | **Ads users only** | Users who installed from your ads (Meta) |

6. **Publish now**, **schedule** (date/time), or **save as draft**.
7. After upload: processing status (thumbnail, video conversion, preview clip) → "Live in app".

Rules:
- A post's audience can't be wider than its channel's (an "Ads users only" channel
  only holds ads-only posts; the panel enforces this).
- Ads users who are not logged in can watch the **preview clip** of premium videos;
  everyone needs login + plan for the full video.

### Posts
- Table: thumbnail, title, channel, audience, premium, status, views, date.
- Bulk actions: publish, hide, change audience, set/unset premium, move folder, delete.
- Preview a post exactly as a given user type would see it (ads / organic, guest / premium).

### Users (owner)
- Search by name, email, user ID.
- Columns: guest/logged in, source (ads / organic), campaign, plan, joined date.
- User detail: first & last touch attribution, joined channels, plan history,
  **ads-content access** (none / waiting / approved / rejected) with Approve / Revoke.
- Organic buyers waiting for approval are **highlighted** in the list.
- **Grant / remove premium** manually (until payments are added).
- Suspend / delete user.

### Plans (owner)
- Edit name, duration, price, perks text, order, active on/off.

### Attribution report (owner)
- By **source** and by **campaign**: installs, guests, logins, premium users, revenue (later).
- Content performance by audience: views from ads users vs organic users.

### Admins (owner)
- Invite, set role, limit to channels, remove, view activity log.

### Settings (owner)
- App links (privacy, terms, refund, community guidelines).
- Download links (organic APK, ads APK).

## 3. Tech

- Next.js (App Router) + Tailwind + shadcn/ui.
- Supabase Auth; access checked by the `admins` table + RLS (admins bypass
  audience filters only inside the panel).
- Uploads: presigned R2 multipart URLs from the `admin-upload-url` Edge Function;
  the browser uploads straight to R2.
- Hosting: Vercel or Cloudflare Pages.
