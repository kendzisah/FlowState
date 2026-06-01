# Analytics Setup — Manual Steps

The Swift code is complete and builds. These dashboard / external steps must be done by hand before paid acquisition launches.

---

## 1. RevenueCat → AppsFlyer S2S (the most important step)

This is **the single most important step in the entire integration**. Without it, AppsFlyer will not receive revenue events and ad campaigns cannot be optimised for trials/subscriptions.

1. Go to https://app.revenuecat.com → FlowState project → **Integrations** → **AppsFlyer**.
2. Choose **App configuration** (separate iOS keys).
3. Paste:
   - **iOS Dev Key**: `9zpuyXbXi542SWZ3sALEb6`
   - **iOS App ID**: `6766418779` (no `id` prefix in the numeric field)
4. **Event name mappings** — paste exactly these into the corresponding fields (overwrites the default `rc_*_event` names):

   | RC field | Value |
   |---|---|
   | RC field | Value | Type |
   |---|---|---|
   | Initial purchase event | `af_purchase` | predefined |
   | Trial started event | `af_start_trial` | predefined |
   | Trial converted event | `af_purchase` | predefined |
   | Renewal event | `af_purchase` | predefined |
   | Non-subscription purchase event | `af_purchase` | predefined |
   | Trial cancelled event | `trial_cancelled` | custom |
   | Cancellation event | `subscription_cancelled` | custom |
   | Expiration event | `subscription_expired` | custom |
   | Billing issue event | `billing_issue` | custom |
   | Product change event | `subscription_changed` | custom |

   Rationale:
   - Every revenue event becomes `af_purchase` so AppsFlyer's ROAS + ad-network optimizers (Meta/Google/TikTok) aggregate them correctly.
   - `af_start_trial` stays distinct so trial campaigns can be optimized before revenue exists.
   - Churn-side events (expiration/cancellation/billing/product change) are **custom** names — useful for our own retention dashboards, irrelevant to ad networks. Per AppsFlyer docs, custom names must NOT be prefixed with `af_` (that prefix is reserved for predefined constants). The bare names above follow this rule.

5. Revenue mode: **Net revenue** (after Apple's cut + estimated taxes).
6. Save. Send a sandbox test purchase from a TestFlight build and confirm the event appears in AppsFlyer dashboard → Raw Data Reports within ~5 minutes.

⚠️ The client AppsFlyer SDK **does not** send `af_purchase` / `af_start_trial` / `af_subscribe`. Verified in [AnalyticsEvent.swift:343-376](../FlowState/Analytics/AnalyticsEvent.swift#L343). Do NOT enable any "send purchases from client" flag — it would double-count.

---

## 2. AppsFlyer dashboard

### a. App Store Connect linkage
Settings → App Settings → confirm `6766418779` and bundle ID `com.flocktechnologies.FlowState` are linked.

### b. SKAN Conversion Studio
Conversion Studio → New Schema → **Conversion + Revenue mode (mode 2)**:

| Window | Conversion event | Revenue mapping |
|---|---|---|
| 0–2 days (window 1) | `signup_completed` → 1<br>`onboarding_completed` → 2<br>`paywall_purchase_initiated` → 3<br>`af_start_trial` (from RC S2S) → 4 | — |
| 3–7 days (window 2) | `af_subscribe` (from RC S2S) → 5 | $1–$9.99 → bucket 1, $10–$24.99 → bucket 2, $25+ → bucket 3 |
| 8–35 days (window 3) | renewal events | same bucketing |

### c. Dashboards to set up
- **Overview**: installs, in-app events, revenue, ROAS by media source.
- **Cohort**: D1/D7/D30 retention; D7/D30 revenue per install.
- **Funnels** → New: `af_app_opened → signup_completed → onboarding_completed → paywall_shown → paywall_purchase_initiated → af_start_trial`.
- **Goals for ad networks**:
  - Meta: `af_start_trial` as primary, `paywall_purchase_initiated` as secondary.
  - Google: same.
  - TikTok: optimize for `af_start_trial` once ≥50/week.

### d. KPIs to watch weekly
- CAC = ad spend / installs.
- CPT = ad spend / trials started.
- T2P (trial-to-paid) = paid conversions / trials started.
- D7 / D30 / D90 ROAS.
- Install→activation rate (`task_completed` within 24h).

---

## 3. PostHog dashboard

### a. Project setup
Already configured via SDK init in [PostHogProvider.swift:30-65](../FlowState/Analytics/PostHogProvider.swift#L30):
- Project ID `436991`
- US host
- Autocapture (screen views + lifecycle + interactions) on
- Session replay off
- Error tracking autoCapture on

### b. Create 6 dashboards

**Dashboard 1 — Onboarding Funnel**
- Insight: Funnel
- Steps:
  1. `app_launched`
  2. `onboarding_started`
  3. `onboarding_step_completed` (step = 5)  ← social proof
  4. `onboarding_step_completed` (step = 6)  ← account created
  5. `onboarding_step_completed` (step = 7)  ← paywall done
  6. `onboarding_step_completed` (step = 19) ← final commit
  7. `onboarding_completed`
- Breakdown: `primary_need`, `neurodivergence_id`
- Window: 24h

**Dashboard 2 — Paywall Funnel**
- Insight: Funnel
- Steps:
  1. `paywall_shown`
  2. `paywall_package_selected`
  3. `paywall_purchase_initiated`
  4. `entitlement_changed` (entitled = true) ← combines all paths
- Breakdown: `source` (onboarding/gate/settings), `package_id`
- Window: 1h

**Dashboard 3 — Activation Funnel**
- Insight: Funnel
- Steps:
  1. `signup_completed`
  2. `onboarding_completed`
  3. `task_created`
  4. `timer_started`
  5. `task_completed`
- Window: 7 days

**Dashboard 4 — Retention**
- Insight: Retention
- Returning event: `app_foregrounded`
- Starting event: `signup_completed`
- Breakdown: `primary_need`
- Period: weekly, 8 weeks

**Dashboard 5 — Errors**
- Insight: Trend
- Event: `$exception`
- Breakdown: `context` (custom property — our context tags)
- Comparison: previous period
- Add alert: spike >2× rolling 7-day average

**Dashboard 6 — Feature Usage**
- Insight: Trend
- Events: `timer_started`, `task_created` (broken down by `source`), `chat_message_sent`, `calendar_import_succeeded`, `energy_set` (broken down by `level`)
- Period: weekly

### c. Enable RevenueCat integration (optional but recommended)
PostHog → Data pipelines → New → RevenueCat. Use the same RC project. PostHog will then see subscription events directly without you having to forward them from the client.

### d. Upload dSYMs for symbolicated crashes
Add a build phase script per https://posthog.com/docs/error-tracking/installation/ios#upload-dsyms. Required for stack traces in PostHog Errors view.

---

## 4. App Store Connect — App Privacy

App Information → App Privacy → Edit. Declare:

| Data type | Linked to user? | Used for tracking? | Purpose |
|---|---|---|---|
| Device ID (IDFA) | Yes (after ATT) | Yes (after ATT) | Third-Party Advertising |
| User ID (CUID = Supabase user ID) | Yes | Yes | Analytics |
| Product Interaction | Yes (after sign-in) | No | Analytics, App Functionality |
| Crash Data | Yes | No | App Functionality |
| Performance Data | Yes | No | App Functionality |

Privacy details are required before the next App Store submission.

---

## 5. ATT prompt copy

Already in [Info.plist:33](../FlowState/Info.plist#L33):

> "FlowState uses this to measure which ads bring you here so we can stop spending on ones that don't. We never sell your data."

You can iterate on the copy. The prompt fires from [ATTManager.swift](../FlowState/Analytics/ATTManager.swift) once the user transitions out of onboarding (to paywall/home/etc.) — see [RootView.swift:122-128](../FlowState/Views/RootView.swift#L122).

---

## 6. Verification walkthrough (do this once dashboards are set up)

In a TestFlight (sandbox) build:

1. **Cold launch** — In Xcode console, confirm "AppsFlyerSDK" + "PostHog" init logs. In PostHog → Live events, confirm `app_launched` arrives.
2. **Walk onboarding** — Clean install. Step through all 20 steps. PostHog Live events should show:
   - `onboarding_started`
   - 20 × `onboarding_step_viewed`
   - 19 × `onboarding_step_completed`
   - `onboarding_marketing_optin`, `_primary_need`, `_neurodivergence`
   - `signup_completed` or `signin_completed`
   - `onboarding_account_created`
   - `notifications_permission_requested/_result`
   - `onboarding_notifications_choice`
   - `onboarding_committed`, `onboarding_completed`
3. **ATT prompt** — Should appear after Step 19 (commit), before paywall. Pick "Ask App Not to Track" → confirm `att_permission_result {status: "denied"}`. On a second device, allow → confirm `granted`. Within 5 min, AppsFlyer raw data should show install events on the granted device with IDFA.
4. **Paywall** — Tap each CTA. PostHog should show `paywall_shown`, `paywall_offerings_loaded`, `paywall_package_selected`, `paywall_purchase_initiated`, `paywall_terms_tapped`, `paywall_privacy_tapped`. AppsFlyer should show `af_content_view` + `af_initiated_checkout`.
5. **Sandbox subscribe** — Complete a sandbox purchase. PostHog: `paywall_purchase_completed`, `entitlement_changed {entitled: true, source: "login"}`. AppsFlyer (via RC S2S, ~5 min delay): `af_start_trial`. **DO NOT** expect `af_purchase` from the client — it's S2S only.
6. **Restore** — Tap Restore on a second device with the same Apple ID. PostHog: `paywall_restore_initiated`, `paywall_restore_completed {entitled: true}`.
7. **Task loop** — Create a task → tap to start → let timer run for 30s → tap complete. PostHog: `task_created`, `add_task_sheet_opened`, `timer_started`, `timer_completed`, `task_completed`, `completion_dialog_shown`, `completion_dialog_dismissed`.
8. **Errors** — Switch to airplane mode → attempt sign-in. PostHog Errors view should show a `$exception` with `context: "auth.signin"`.
9. **Identify/reset** — Sign in. PostHog identifies the user. Settings → Sign out. PostHog `reset` fires, distinct_id reverts to anonymous.
10. **Settings** — Change theme. PostHog: `theme_changed`. Toggle notifications. PostHog: `notifications_toggled`. Tap "Manage subscription" or "Go Pro". PostHog tracks the right event.

If any of these don't fire, search [analytics/validation-report.md](validation-report.md) for the event and check the listed callsite is reached.

---

## File map

Code:
- [FlowState/Analytics/](../FlowState/Analytics/) — module with 8 files
- [FlowState/Store/SubscriptionManager+AppsFlyer.swift](../FlowState/Store/SubscriptionManager+AppsFlyer.swift) — RC↔AF bridging
- [FlowState/Store/AppStore+Analytics.swift](../FlowState/Store/AppStore+Analytics.swift) — `analyticsTraits()` helper

Specs (authoritative — implementation followed these):
- [analytics/events-index.md](events-index.md) — every event with callsite
- [analytics/appsflyer-spec.md](appsflyer-spec.md) — AppsFlyer integration spec
- [analytics/posthog-spec.md](posthog-spec.md) — PostHog integration spec
- [analytics/error-tracking-spec.md](error-tracking-spec.md) — per-catch instrumentation
- [analytics/validation-report.md](validation-report.md) — gap audit + verification log
- [analytics/SETUP.md](SETUP.md) — this file
