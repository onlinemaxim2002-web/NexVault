# Compliance & Policies

> Not legal advice. Have a lawyer review the final policy texts before launch.

## 1. India

- **IT Act 2000 & IT (Intermediary Guidelines) Rules 2021**: publish a grievance
  officer (name, contact), acknowledge complaints within 24h, resolve within 15 days,
  remove non-consensual intimate content within 24h, and act on government/court orders.
- **DPDP Act 2023**: clear consent notice, purpose limitation, rights to access,
  correct, and erase data, breach notification, and a contact for data requests.
- **GST**: invoices for paid plans; Play Billing handles GST for in-app purchases.
- **Consumer Protection (E-Commerce) Rules**: clear pricing, refund terms, and
  grievance contact.

## 2. Google Play

- Data Safety form that matches actual data collection (incl. AdMob/Firebase SDKs).
- Account deletion available in-app **and** at a public web URL.
- User-generated content policy (Channels): in-app reporting, blocking, moderation,
  and terms that prohibit objectionable content.
- Subscriptions policy: show price, period, and auto-renew terms clearly; easy cancellation.
- Permissions: photos/videos via the Photo Picker or `READ_MEDIA_*` with justification;
  avoid `MANAGE_EXTERNAL_STORAGE` unless strictly needed.
- Use Play Billing for digital goods (user-choice billing is optional in India).

## 3. Content safety

- Prohibited: CSAM, non-consensual intimate imagery, piracy/copyright infringement,
  malware, terrorism, hate, and illegal goods.
- Detection: hash matching against known CSAM databases (e.g. via partner APIs),
  an NSFW classifier on public content, ClamAV on shared files.
- Copyright: takedown request form, repeat-infringer policy, counter-notice process.
- Enforcement levels: content removal → link disable → channel suspension → account ban.

## 4. Policy pages to write (our own text)

| Page | Must include |
|---|---|
| Privacy Policy | Data collected, purposes, SDKs/third parties, retention, rights, grievance officer, contact |
| Terms & Conditions | Eligibility (13+/18+), acceptable use, storage/fair-use limits, inactivity policy, subscriptions, termination, liability, governing law (India) |
| Refund Policy | Play Store refund route, Razorpay refunds, time windows, non-refundable cases |
| Community Guidelines | Channel rules, prohibited content, reporting, enforcement |
| Delete Account | Steps in-app and on the web, what is deleted, grace period, retention for legal reasons |

Jollify's pages can be used as a **structural checklist only**. Do not copy their text.
