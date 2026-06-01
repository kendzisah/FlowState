# Widgets V1 — Implementation Log + QA Checklist

## What shipped

5 widget surfaces, all in the existing `FlowStateActivityExtensionExtension` target. Build: ✅ `xcodebuild ... build` → **BUILD SUCCEEDED** on both main app and extension.

### Files added

**Main app — `FlowState/Widgets/`**
- `Shared/WidgetSnapshot.swift` — Codable payload (mirrored)
- `Shared/WidgetSnapshotStore.swift` — App Group UserDefaults R/W (mirrored)
- `Shared/DeepLinkRoute.swift` — typed `flowstate://` parser
- `AppIntents/PendingWidgetAction.swift` — action queue (mirrored)
- `AppIntents/StartTaskIntent.swift` (mirrored)
- `AppIntents/ParkTaskIntent.swift` (mirrored)
- `AppIntents/ResumeTaskIntent.swift` (mirrored)
- `AppIntents/StopTaskIntent.swift` (mirrored)
- `AppIntents/SetEnergyIntent.swift` (mirrored)
- `WidgetSnapshotWriter.swift` — builds + persists the snapshot

**Main app — `FlowState/URL/`**
- `DeepLinkRouter.swift` — `.onOpenURL` handler + pending-action drainer

**Widget extension — `FlowStateActivityExtension/`**
- `Shared/WidgetSnapshot.swift` (mirror)
- `Shared/WidgetSnapshotStore.swift` (mirror)
- `Shared/EnergyLevelLite.swift` — extension-safe enum + `Color(hex:)`
- `Shared/PendingWidgetAction.swift` (mirror)
- `AppIntents/{Start,Park,Resume,Stop,SetEnergy}TaskIntent.swift` (mirrors)
- `Widgets/SharedTimelineProvider.swift` — single provider for all 4 home-screen widgets
- `Widgets/LockScreenRectangularWidget.swift`
- `Widgets/SmallRecommendationWidget.swift`
- `Widgets/MediumTop3Widget.swift`
- `Widgets/SmallParkedWidget.swift`
- `FlowStateActivityExtension.entitlements` — adds `group.com.flocktechnologies.FlowState` to extension

### Files modified

- `FlowState/Info.plist` — registered `flowstate://` URL scheme
- `FlowState/FlowStateApp.swift` — `.onOpenURL`, drain queue on launch + foreground, initial snapshot refresh
- `FlowState/Store/AppStore+Timer.swift` — `LiveActivityController.start` now takes `taskID`; `setComplete` / `setParked` calls; snapshot refresh after every timer mutation
- `FlowState/Store/AppStore+Energy.swift` — snapshot refresh after every energy mutation
- `FlowState/Store/AppStore+Analytics.swift` — weak static `activeInstanceForWidgetRefresh`
- `FlowState/Sync/ModelContext+Sync.swift` — snapshot refresh in `saveAndSync()`
- `FlowState/LiveActivity/FlowStateActivityAttributes.swift` — added `Phase` enum, `parkedCount`, `taskID`
- `FlowState/LiveActivity/LiveActivityController.swift` — `setComplete()` + `setParked(parkedCount:)`; auto-detect `.lastMinute` phase
- `FlowStateActivityExtension/FlowStateActivityAttributes.swift` — mirror of main app changes
- `FlowStateActivityExtension/FlowStateActivityExtensionLiveActivity.swift` — 4-phase rendering with Park/Stop AppIntent buttons + last-minute pulse
- `FlowStateActivityExtension/FlowStateActivityExtensionBundle.swift` — registers all 5 widgets
- `FlowState.xcodeproj/project.pbxproj` — `CODE_SIGN_ENTITLEMENTS` set on extension target; `.entitlements` added to membership exceptions so it doesn't compile

## Architectural choices (recap)

| Decision | Implementation |
|---|---|
| Palette: keep earthy | Widgets use `EnergyLevelLite.hexString` (mirror of main app values) |
| Tap actions: AppIntents + URLs | All 5 AppIntents enqueue to App Group queue; main app drains on foreground. URL scheme handles external navigation |
| Foggy = rest mode | `SmallRecommendationView.foggyRestView` + `MediumTop3View.foggyRestView` show calming rest copy |
| Single extension target | All widgets in `FlowStateActivityExtensionBundle.body` |
| App Group UserDefaults | `group.com.flocktechnologies.FlowState`; JSON snapshot under key `widget.snapshot.v1`; action queue under `widget.action.queue.v1` |
| No per-second widget refresh | Active timer in widgets uses `Text(timerInterval:countsDown:)` — system ticks for free |

## Background question — answered in code

**Yes, the Live Activity extension handles the backgrounded session display.** It already existed; we extended it to host the home-screen widgets too. No new target was created. ActivityKit ticks the timer via `Text(timerInterval:)` in the extension process — main app can be suspended/killed without breaking the lock-screen countdown. Home-screen widgets don't need background execution; they're driven by `SharedTimelineProvider` which the system polls every ~30 min plus on explicit `WidgetCenter.shared.reloadAllTimelines()` from the main app after every state mutation.

## QA checklist (run on a TestFlight / sandbox build)

1. **Install + add widgets**
   - Install build on physical device.
   - Long-press home screen → tap + → search "FlowState".
   - Add each of the 4 home-screen widgets (Recommendation, Top 3, Parked Queue, plus the medium for the LockScreen widget which appears under the lock-screen widget gallery).
   - Each renders cleanly. No crashes, no "could not load" errors.

2. **Cold launch with no state**
   - Recommendation widget: shows energy-dot row prompting check-in.
   - Top 3 widget: shows "How's your energy?" prompt.
   - Parked Queue: shows "Nothing parked" + Park This educational copy.
   - Lock screen rectangular: shows "Energy check-in pending".

3. **Set energy from widget**
   - Tap "Steady" dot in Recommendation widget.
   - App opens; energy is set; widget reloads showing the top steady task with Start button.

4. **Tap Start in Recommendation widget**
   - App opens to Timer screen; session starts immediately.
   - Within 1s, both Recommendation widget and Top 3 widget transition to "In session" rendering.
   - Lock screen widget shows countdown.
   - Live Activity appears on Dynamic Island + lock screen.

5. **Last-minute pulse**
   - Start a 5-min countdown. Wait until ~60s remaining.
   - Live Activity text turns warm red (`#E25E5E`) and gently pulses every ~2.4s.
   - At 0s, no pulse — the activity flips into "Session complete" banner.

6. **Park This from Live Activity**
   - Start a session. Open Dynamic Island expanded view.
   - Tap "Park This" → app opens briefly → action drains → task is parked.
   - Live Activity flips to "Parked at MM:SS" banner for 10s, then auto-ends.
   - Parked Queue widget on home screen shows the new task within 1s.

7. **Stop from Live Activity**
   - Start a session. Open Dynamic Island expanded view.
   - Tap "Stop" → app opens → task is marked complete.
   - Live Activity flips to "Session complete" banner with checkmark for 10s.

8. **Resume from Parked widget**
   - With a parked task visible, tap Resume.
   - App opens to Timer; session restored with parked elapsed seconds.
   - Parked Queue count decrements.

9. **Foggy state**
   - In app, switch energy to Foggy.
   - Recommendation widget shows "☁️ Foggy / Your brain needs a break. Recovery counts."
   - Top 3 widget shows "Today is a rest day. Recovery counts." (No tasks listed.)

10. **URL deep links**
    - From Safari: `flowstate://parked` → app opens (no error).
    - `flowstate://add` → AddTaskSheet appears.
    - `flowstate://checkin/steady` → energy is set to steady; main view updates.

11. **Sign out**
    - Sign out from Settings.
    - Widgets revert to empty / no-checkin states.
    - Pending widget actions for the previous user are not applied (drained but no matching task UUIDs).

12. **App killed during session**
    - Start a 10-min countdown. Swipe app away in app switcher.
    - Live Activity continues ticking on lock screen.
    - Re-open app; foreground delta reconciles elapsed time; widgets refresh to new state.

## Known V1 limitations (intentional)

- **All AppIntents use `openAppWhenRun = true`**: Park This / Stop from the Live Activity open the app briefly to perform the action. The plan flagged converting these to `LiveActivityIntent` (in-process) as a V2 follow-up.
- **No second-by-second snapshot writes on `tick()`**: The active timer in widgets uses `Text(timerInterval:)` which the system ticks; we don't push every second.
- **Top 3 sort uses `AppStore.sortedTasks`**: same logic the in-app list uses, so behaviour matches the app exactly.
- **Manual file mirroring between targets**: 8 files are duplicated with a `// MUST stay byte-identical with X` header (same pattern already used for `FlowStateActivityAttributes.swift`). Easier than fighting the synchronized-group Target Membership exception system.

## Done

5 surfaces live. Build green. Walkthrough is repeatable on real hardware. Ready for TestFlight QA.
