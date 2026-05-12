import Foundation

/// Tracks when to ask the user for an App Store review. Doesn't trigger the
/// prompt itself — that requires SwiftUI's `requestReview` environment action,
/// which lives in `RootView`. This manager just maintains the eligibility
/// signal via `AppStore.pendingReviewRequest`.
///
/// Triggers:
///   - Task-completion milestone: every Nth completed task (default 5).
///   - Day-7 return: if 7+ days have passed since first launch and the user
///     has never been prompted, ask once.
///
/// Guards:
///   - Never prompts more than once per 90 days, regardless of trigger.
///   - iOS rate-limits `requestReview` to ~3 prompts per 365 days anyway, so
///     additional callsites are safe even if our tracking drifts.
@MainActor
enum ReviewPromptManager {
    private static let key_completedSincePrompt = "reviewPrompt.completedSince"
    private static let key_lastPromptDate       = "reviewPrompt.lastDate"
    private static let key_firstLaunchDate      = "reviewPrompt.firstLaunchDate"

    private static let completionThreshold = 5
    private static let minDaysBetweenPrompts: Double = 90
    private static let daySevenReturnDays: Double = 7

    /// Call on every successful task completion. Increments the running count
    /// and flips the prompt flag on `store` if the user crosses the threshold.
    static func recordTaskCompletion(store: AppStore) {
        let defaults = UserDefaults.standard
        let next = defaults.integer(forKey: key_completedSincePrompt) + 1
        defaults.set(next, forKey: key_completedSincePrompt)

        if next >= completionThreshold && enoughTimeSinceLastPrompt() {
            store.pendingReviewRequest = true
        }
    }

    /// Call when the app foregrounds. If the user is on day 7+ and has never
    /// been prompted, request a review.
    static func recordAppForeground(store: AppStore) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: key_firstLaunchDate) == nil {
            defaults.set(Date(), forKey: key_firstLaunchDate)
            return
        }
        guard defaults.object(forKey: key_lastPromptDate) == nil,
              let firstLaunch = defaults.object(forKey: key_firstLaunchDate) as? Date,
              Date().timeIntervalSince(firstLaunch) >= daySevenReturnDays * 86400 else {
            return
        }
        store.pendingReviewRequest = true
    }

    /// `RootView` calls this after firing `requestReview` so the next
    /// eligibility check accounts for the prompt we just showed.
    static func markPromptShown() {
        let defaults = UserDefaults.standard
        defaults.set(Date(), forKey: key_lastPromptDate)
        defaults.set(0, forKey: key_completedSincePrompt)
    }

    private static func enoughTimeSinceLastPrompt() -> Bool {
        guard let last = UserDefaults.standard.object(forKey: key_lastPromptDate) as? Date else {
            return true
        }
        return Date().timeIntervalSince(last) >= minDaysBetweenPrompts * 86400
    }
}
