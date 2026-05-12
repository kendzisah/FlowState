import Foundation
import Observation

/// App-wide observable that tracks whether the proxy has rejected us with a
/// `daily_quota_exceeded` 429. Chat UI binds to `isLocked` to disable input;
/// other AI callers (event classifier, anytime auto-sorter) read this before
/// even making a network call so they skip straight to heuristic fallback.
///
/// State is cached in UserDefaults so the lock persists across launches until
/// the recorded `resetsAt` passes.
@MainActor
@Observable
final class AIQuotaState {
    static let shared = AIQuotaState()

    private static let storageKey = "aiQuota.resetsAt"

    /// When the daily cap will reset (server-supplied UTC midnight). Nil when
    /// quota is healthy. Setting this also persists to UserDefaults.
    private(set) var resetsAt: Date?

    var isLocked: Bool {
        guard let resetsAt else { return false }
        return resetsAt > Date()
    }

    private init() {
        let stored = UserDefaults.standard.object(forKey: Self.storageKey) as? Date
        if let stored, stored > Date() {
            self.resetsAt = stored
        } else if stored != nil {
            // Stale lock — clean it up so we don't ship a "locked" flash on launch.
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
        }
    }

    func markQuotaExceeded(resetsAt: Date) {
        self.resetsAt = resetsAt
        UserDefaults.standard.set(resetsAt, forKey: Self.storageKey)
    }

    /// Drops the lock if the reset time has passed. Safe to call repeatedly
    /// (e.g. from a chat-view polling timer) — no-op when there's nothing to clear.
    func clearIfExpired() {
        guard let resetsAt, resetsAt <= Date() else { return }
        self.resetsAt = nil
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    /// Human-readable "Resets at 4:00 PM today" / "Resets tomorrow at 4:00 PM".
    /// Used by the chat banner and the in-chat system message.
    func formattedResetTime() -> String {
        guard let resetsAt else { return "soon" }
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        let time = timeFormatter.string(from: resetsAt)
        if calendar.isDateInToday(resetsAt) {
            return "today at \(time)"
        } else if calendar.isDateInTomorrow(resetsAt) {
            return "tomorrow at \(time)"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateStyle = .medium
            dayFormatter.timeStyle = .short
            return "on \(dayFormatter.string(from: resetsAt))"
        }
    }
}
