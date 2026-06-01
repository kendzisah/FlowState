import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class AppStore {
    // Energy
    var energyLevel: EnergyLevel? = nil
    var energySetAt: Date? = nil
    var lastPromptAt: Date? = nil           // PHASE B: re-prompt logic
    var peekList: Bool = false

    // Timer
    var activeTask: Task? = nil
    var timerMode: TimerMode = .countdown
    var timerDurationSeconds: Int = 25 * 60
    var timerSecondsRemaining: Int = 25 * 60
    var timerElapsedSeconds: Int = 0
    var timerRunning: Bool = false
    var backgroundedAt: Date? = nil

    // UI
    var showAddTask: Bool = false
    var showEnergySwitcher: Bool = false
    var showDurationPicker: Bool = false
    var showSettings: Bool = false
    var completionDialog: CompletionDialogState? = nil

    /// Set to `true` when `ReviewPromptManager` decides the App Store review
    /// prompt is due. `RootView` watches this and fires the SwiftUI
    /// `requestReview` action, then flips it back to `false`. Kept on
    /// AppStore (rather than ReviewPromptManager) so the trigger crosses the
    /// non-View → View boundary without coupling AppStore+Timer to SwiftUI.
    var pendingReviewRequest: Bool = false

    // Theme — system follow with override. Stored so @Observable tracks changes;
    // didSet persists to UserDefaults.
    var themeMode: ThemeMode = (UserDefaults.standard.string(forKey: "themeMode")
        .flatMap { ThemeMode(rawValue: $0) }) ?? .system {
        didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode") }
    }

    // Internal ticker — populated in Chunk 6
    @ObservationIgnored
    var ticker: Timer? = nil

    var energyIsActiveToday: Bool {
        guard let setAt = energySetAt else { return false }
        return Calendar.current.isDateInToday(setAt)
    }

    /// Phase B re-prompt: if the last prompt was >3h ago AND no timer is running,
    /// the foreground transition resets the check-in. Called from handleScenePhase.
    func shouldRepromptOnForeground() -> Bool {
        guard let last = lastPromptAt else { return false }
        return Date().timeIntervalSince(last) > 3 * 3600
    }

    func resetEnergyForRePrompt() {
        energyLevel = nil
        energySetAt = nil
        peekList = false
    }

    /// Notification preference. Default true; user can disable in Settings.
    ///
    /// `didSet` also drives routine-reminder lifecycle: flipping to `false`
    /// cancels every pending routine notification immediately; flipping back
    /// to `true` rebuilds them via `NotificationManager.refreshAllRoutineReminders`
    /// on the next foreground tick (we don't have a ModelContext here).
    var notificationsEnabled: Bool = (UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
            if !notificationsEnabled {
                NotificationManager.cancelAllRoutineReminders()
                NotificationManager.cancelAllTaskReminders()
                NotificationManager.cancelCompletion()
            }
            // Re-enabling triggers refresh from `FlowStateApp` on the next
            // `scenePhase == .active`, which is the canonical refresh edge.
        }
    }

    /// First-launch flag. Used by RootView to gate onboarding.
    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    /// Paywall entitlement. Source of truth is RevenueCat's `customerInfoStream`,
    /// which `SubscriptionManager.bind(to:)` mirrors here. UserDefaults caches the
    /// last-known value so cold launches don't flash the paywall before the SDK
    /// returns (the cached value is overwritten as soon as `customerInfoStream`
    /// emits, which happens within milliseconds of `Purchases.configure(...)`).
    var entitled: Bool = (UserDefaults.standard.object(forKey: "entitled") as? Bool) ?? false {
        didSet { UserDefaults.standard.set(entitled, forKey: "entitled") }
    }

    // MARK: - Onboarding-derived profile

    var marketingOptIn: Bool? = {
        guard let v = UserDefaults.standard.object(forKey: "marketingOptIn") as? Bool else { return nil }
        return v
    }() {
        didSet {
            if let v = marketingOptIn { UserDefaults.standard.set(v, forKey: "marketingOptIn") }
            else { UserDefaults.standard.removeObject(forKey: "marketingOptIn") }
        }
    }

    var primaryNeed: PrimaryNeed? = (UserDefaults.standard.string(forKey: "primaryNeed")
        .flatMap { PrimaryNeed(rawValue: $0) }) {
        didSet { UserDefaults.standard.set(primaryNeed?.rawValue, forKey: "primaryNeed") }
    }

    var neurodivergenceSelfId: NeurodivergenceSelfID? = (UserDefaults.standard.string(forKey: "neurodivergenceSelfId")
        .flatMap { NeurodivergenceSelfID(rawValue: $0) }) {
        didSet { UserDefaults.standard.set(neurodivergenceSelfId?.rawValue, forKey: "neurodivergenceSelfId") }
    }

    var calendarImported: Bool = UserDefaults.standard.bool(forKey: "calendarImported") {
        didSet { UserDefaults.standard.set(calendarImported, forKey: "calendarImported") }
    }

    /// Tip-card dismissals on the Calendar tab.
    var tipSmartWidgetsDismissed: Bool = UserDefaults.standard.bool(forKey: "tipSmartWidgetsDismissed") {
        didSet { UserDefaults.standard.set(tipSmartWidgetsDismissed, forKey: "tipSmartWidgetsDismissed") }
    }
    var tipImportCalendarDismissed: Bool = UserDefaults.standard.bool(forKey: "tipImportCalendarDismissed") {
        didSet { UserDefaults.standard.set(tipImportCalendarDismissed, forKey: "tipImportCalendarDismissed") }
    }

    /// Stable user identifier returned by Sign in with Apple. Nil if email auth was chosen
    /// or if onboarding is incomplete.
    var appleUserIdentifier: String? = UserDefaults.standard.string(forKey: "appleUserIdentifier") {
        didSet { UserDefaults.standard.set(appleUserIdentifier, forKey: "appleUserIdentifier") }
    }

    /// Email captured during email-auth path. Phase A is local-only — no password storage.
    var userEmail: String? = UserDefaults.standard.string(forKey: "userEmail") {
        didSet { UserDefaults.standard.set(userEmail, forKey: "userEmail") }
    }
}

enum PrimaryNeed: String, Codable, CaseIterable {
    case organize, remember, prioritize, routines, focus, other
}

enum NeurodivergenceSelfID: String, Codable, CaseIterable {
    case yes, thinkSo, no, unknown
}
