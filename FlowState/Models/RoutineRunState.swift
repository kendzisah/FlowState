import Foundation

/// In-memory state for a "routine group run" — the Calendar Start button that
/// walks the user through a group's tasks one at a time under a single shared
/// countdown. Not persisted: a run lives for the session. The underlying Tasks
/// are persisted (each is marked complete as the user finishes it), so a run
/// lost to an app kill degrades gracefully — the user just re-starts and only
/// the still-incomplete tasks are queued.
///
/// While a run is *active*, the live countdown lives in `AppStore.timerSeconds`
/// fields (so it reuses the timer ticker / background handling). While *paused*,
/// the remaining seconds are stashed in `stashedSecondsRemaining` so the
/// Calendar can offer a Resume that picks up exactly where it left off.
struct RoutineRunState: Equatable {
    let groupID: UUID
    let groupTitle: String
    let groupEmoji: String?
    /// Tasks not yet completed, in run order. Index 0 is the current task
    /// (mirrored into `AppStore.activeTask` while active).
    var remainingTaskIDs: [UUID]
    /// Tasks already completed in this run (for the X/Y progress label).
    var completedCount: Int
    /// Total tasks in the group for today (completed + remaining).
    let totalCount: Int
    /// Group run length; the countdown total.
    let totalDurationSeconds: Int
    /// Seconds left when paused. Meaningful only for a paused run.
    var stashedSecondsRemaining: Int

    /// 1-based position of the current task, for "2 / 5" style labels.
    var currentPosition: Int { min(completedCount + 1, totalCount) }
}
