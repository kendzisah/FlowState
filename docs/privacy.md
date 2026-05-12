---
layout: default
title: Privacy Policy — FlowState
---

# Privacy Policy

**Last updated: 12 May 2026**

This Privacy Policy describes how FlowState ("we", "us", "the app") collects,
uses, and protects your information when you use the FlowState iOS app.

## 1. Information We Collect

### Account information
When you create an account, we collect:
- Your email address (collected via Apple Sign In or email/password sign-up).
- An Apple user identifier (only when you choose Sign in with Apple).

### Content you create
We store the content you create in the app:
- Tasks (title, energy tag, scheduled date, completion state).
- Routines and routine groups (title, emoji, slot, recurrence rule, optional
  energy tag).
- Parked tasks and elapsed timer state.
- Imported calendar events (title, time, source calendar name).

### Subscription information
If you subscribe to FlowState Pro, our payment partner (RevenueCat) receives
the receipt data from Apple to validate your subscription and entitlement
status. We do not receive or store your payment card details — those stay
with Apple.

### Local-only data
The following data **stays on your device** and is not transmitted to our
servers:
- Calendar events read from the system Calendar via EventKit. We only read
  your calendars to display events alongside your tasks; we do not upload
  event content to our servers.
- Microphone audio and speech transcriptions used for the in-app dictation
  feature. Audio is processed by Apple's on-device Speech framework when
  available; transcribed text is only sent to OpenAI if you use the AI task
  classifier (see Section 3).

## 2. How We Use Your Information

We use the information we collect to:
- Provide and operate the FlowState service (sync your tasks across your
  devices, materialize daily routine instances, surface energy-matched tasks).
- Manage your subscription and entitlement.
- Communicate with you about account or service changes when necessary.
- Protect against abuse and debug technical issues.

We do not use your information for advertising. We do not sell your data.

## 3. Third-Party Services

FlowState relies on the following third-party services. Each operates under
its own privacy policy.

| Service | Purpose | Data shared |
| --- | --- | --- |
| **Apple (Sign in with Apple, App Store, EventKit, Speech)** | Authentication, payment, optional calendar read, speech-to-text | Email, Apple user ID, purchase receipts, calendar reads (device-local), speech audio (device-local when supported) |
| **Supabase** | Authenticated database for tasks, parked tasks, imported event metadata | Authenticated user ID, content you create |
| **RevenueCat** | Subscription state, paywall offerings, receipt validation | Apple user ID, subscription receipt, entitlement status |
| **OpenAI** | AI suggestions (energy classification of tasks/events, task generation from natural language) | The task title or event text being classified — only when you trigger an AI feature |

Apple's privacy policy: <https://www.apple.com/legal/privacy/>
Supabase's privacy policy: <https://supabase.com/privacy>
RevenueCat's privacy policy: <https://www.revenuecat.com/privacy>
OpenAI's privacy policy: <https://openai.com/policies/privacy-policy>

## 4. Data Retention

We retain your content for as long as your account exists. When you delete
your account, the account record and your tasks, routines, parked tasks, and
imported event rows are removed from our database. Subscription receipts may
be retained by Apple and RevenueCat per their own retention policies.

## 5. Your Rights

You can:

- **Access and edit** any content you've created from within the app.
- **Delete your account and all associated data** from Settings → Account →
  Delete account. This triggers a server-side delete of your account and
  every row associated with it.
- **Export or request a copy** of your data by emailing
  [dzisahken10@gmail.com](mailto:dzisahken10@gmail.com). We will respond
  within 30 days.
- **Manage or cancel your subscription** at any time from your iOS Settings →
  Apple ID → Subscriptions.

If you are in the EU/UK (GDPR) or California (CCPA), you have additional
rights, including the right to lodge a complaint with your local data
protection authority. Contact us at the email below to exercise these rights.

## 6. Children's Privacy

FlowState is not directed at children under 13 (or the applicable age of
digital consent in your jurisdiction). We do not knowingly collect personal
information from children. If you believe we have, please contact us and we
will delete the information promptly.

## 7. Security

We use industry-standard transport encryption (HTTPS/TLS) for data in transit.
At rest, your content is stored in Supabase's managed Postgres infrastructure
with row-level security policies that scope every read to the authenticated
user. No security system is perfect; please contact us at the email below if
you suspect a security issue.

## 8. Changes to This Policy

We may update this Privacy Policy from time to time. The "Last updated" date
at the top reflects the most recent change. Material changes will be
communicated in-app or by email.

## 9. Contact

Questions, requests, or concerns:

**Email:** [dzisahken10@gmail.com](mailto:dzisahken10@gmail.com)
