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
    var notificationsEnabled: Bool = (UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    /// First-launch flag. Used by RootView to gate onboarding.
    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    /// Paywall entitlement. Default true (Phase A still works); paywall flips false on trial expiry.
    var entitled: Bool = (UserDefaults.standard.object(forKey: "entitled") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(entitled, forKey: "entitled") }
    }
}
