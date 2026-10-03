# UPI Payments (UPI Intent)

Customers pay for a plan with any UPI app (Google Pay, PhonePe, Paytm, BHIM…).
Money goes straight to the owner's UPI ID; there is no payment gateway.

- UPI ID: **2728412a@bandhan**. Payee name: **Cloud Storage**. You can change
  both in the admin panel under **Payments → UPI settings**.
- Plans and prices come from the `plans` table: Trial ₹69 / 2 days,
  Silver ₹129 / 7 days, Gold ₹259 / 30 days, Platinum ₹599 / 180 days,
  Diamond ₹999 / 365 days.

## Flow

```
App: Premium → pick plan → Next (login if guest)
  └─ create_payment_order(plan)        server picks amount, reference CSyymmdd+12 hex
App: saves order → opens  upi://pay?pa=…&pn=Cloud%20Storage&tr=<ref>&am=69.00&cu=INR&tn=Cloud%20Storage%20<ref>
     through a chooser ("No UPI app found" message if none is installed)
UPI app → answer → MainActivity.onActivityResult saves it on the phone at once
App (background): refresh login → report_payment_result(order, raw) → retry with
     backoff until the server accepts → delete the saved copy
Server: checks → activate_payment(…, 'upi_app') or stays PENDING for the owner
App: status screen polls every 5 s (10 min) and on resume
Owner: admin panel → Payments → check the bank statement → Mark as paid (UTR) / Revoke
```

## Server rules (database functions)

| Function | Who | What |
|---|---|---|
| `create_payment_order(plan_id)` | logged-in users | Amount = plan price × 100 paise. Reuses the open order for the same plan (24 h) and cancels the user's other open orders. |
| `report_payment_result(order_id, raw)` | the order's owner | Saves the raw answer and parsed status. **SUCCESS** activates only if txnRef (if present) = this order's reference, a transaction id exists (ApprovalRefNo, else txnId, 6–40 letters/digits), that id was never used, and the order is less than 2 hours old. **FAILURE** marks the order failed. Anything else stays pending with the reason saved. |
| `activate_payment(order, amount, utr, source)` | **server only** (not the app) | Locks the order, idempotent, amount must match, each UTR once (unique index), then grants the plan: new expiry = max(now, current expiry) + plan length. |
| `admin_mark_payment_paid(order, utr, amount)` | owner | Calls `activate_payment(…, 'admin')`. A UTR is always required. |
| `admin_revoke_payment(order, reason)` | owner | Ends the plan that order granted and marks it revoked. |
| `admin_payment_orders(filter)` | owner | List for the panel (all / pending / success / failed / cancelled / revoked). |
| `provider_confirm_payment(reference, amount, utr)` | service role only | Hook for a bank/provider callback (source `provider_api`). |
| `cancel_stale_payment_orders()` | pg_cron every 30 min | Orders still open after 24 h → cancelled. |

The app can only **read its own orders**. It cannot insert or update orders,
subscriptions or settings (RLS + revoked grants), and no secret key is in the app.

## Honest limits

- A UPI app's "SUCCESS" is produced **on the customer's phone**. A technical user
  can forge it. The checks (matching reference, real-looking unused transaction id,
  2-hour window, one-time use) make that harder, not impossible.
- So: **compare successes with your bank statement** (amount + UTR) and use
  **Revoke** when a payment isn't there.
- Personal UPI IDs: some UPI apps limit or block intent payments to personal
  (non-merchant) UPI IDs, or don't return an answer. Then the order stays pending
  and you confirm it with **Mark as paid**. A merchant UPI ID from your bank
  avoids most of this.
- Fully trusted, automatic verification needs your bank's **UPI transaction-status
  API or payment callback**. `supabase/functions/upi-webhook` is ready for that
  (not deployed; adapt its `parse()`/`verify()` to the bank's format).

## What to ask your bank (Bandhan Bank or a payment aggregator)

1. A **merchant / business UPI ID (VPA)** for the business, not a personal one.
2. **Payment notification (webhook / callback)** for every credit to that VPA,
   containing: the `tr` transaction reference we send, amount, **UTR/RRN**, payer
   VPA, status, time; signed (HMAC or similar) so it can be verified.
3. Or a **transaction-status API**: look up a payment by our reference (`tr`) or
   by UTR, returning status + amount.
4. Test (UAT) credentials and documentation for both.

## ₹1 test procedure

1. In the admin panel, temporarily add a plan priced ₹1 (Plans page) or edit the
   Trial price to 1. Remember to change it back.
2. On an Android phone with a UPI app: install the new APK, log in, Premium →
   pick the ₹1 plan → Next. The chooser opens; pick your UPI app.
3. Check the UPI app shows payee **Cloud Storage**, UPI ID 2728412a@bandhan,
   amount **₹1.00**, note "Cloud Storage CS…".
4. Pay. Back in the app you should see either **Payment successful!** (the app
   answered SUCCESS with a transaction id) or **Payment verification is pending**.
5. Admin panel → Payments: find the order number, look at the raw UPI answer,
   then compare with your bank statement / UPI app history (amount + UTR).
6. If it was pending: **Mark as paid** with the UTR from the bank and amount 1.
   The app switches to "Payment successful" within ~5 s.
7. Try **Revoke** on it: the plan disappears from the app.
8. Extra checks: start a payment and back out of the UPI app (stays pending /
   failed, never success); start a payment, swipe the app away while the UPI app
   is open, pay, reopen the app (status screen comes back and the answer is sent).
9. Restore the plan price.

## Buying flow in the app

1. Everyone starts as a guest automatically (organic and ads installs alike).
2. Premium → select a plan → **Next** → pop-up "Please log in" → **Log in**.
3. Login screen: **Sign in with google** or **Login with email** (email screen has
   Forgot password? and Create Account), with the Privacy Policy and Terms links.
4. After login the user is back on Premium with the plan still selected and the
   button reads **Continue to payment** → UPI app chooser.

Google sign-in needs, once, in the Supabase dashboard:
- Authentication → Sign In / Providers → **Google**: enable, paste the Client ID
  and Client Secret of a Google Cloud OAuth client (type "Web application" whose
  Authorized redirect URI is `https://lcfiohprmviolzwglkhm.supabase.co/auth/v1/callback`).
- Authentication → URL Configuration → Redirect URLs: add
  `com.cloudstorage.app://login-callback` (also used by password-reset emails).

Until Google is enabled, the app shows "Google sign-in is not set up yet. Please
log in with email."
