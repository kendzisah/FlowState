import ActivityKit
import Foundation

/// Wraps ActivityKit for the FlowState focus session.
///
/// Lifecycle:
///   • `start(...)` requests a fresh activity when the user begins a task.
///   • `update(...)` pushes per-second-or-coarser state changes (mode, time,
///     phase). Per-second ticks are NOT pushed here — the Live Activity UI
///     uses `Text(timerInterval:countsDown:)` which ticks in-system.
///   • `setComplete(...)` and `setParked(...)` flip the activity into the
///     post-session banner states for 10s, then `end()` dismisses.
///   • `end()` cancels immediately.
@MainActor
enum LiveActivityController {
    private static var current: Activity<FlowStateActivityAttributes>?
    private static let postSessionLingerSeconds: TimeInterval = 10

    static func start(
        taskID: String,
        taskTitle: String,
        energyHex: String,
        mode: TimerMode,
        secondsRemaining: Int,
        secondsElapsed: Int,
        totalDuration: Int
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()

        let now = Date()
        let endDate: Date? = mode == .countdown
            ? now.addingTimeInterval(TimeInterval(secondsRemaining))
            : nil

        let attributes = FlowStateActivityAttributes(
            taskTitle: taskTitle,
            energyHex: energyHex,
            mode: mode == .countdown ? .countdown : .countup,
            taskID: taskID
        )
        let state = FlowStateActivityAttributes.State(
            secondsRemaining: secondsRemaining,
            secondsElapsed: secondsElapsed,
            startDate: now,
            endDate: endDate,
            phase: phaseFor(secondsRemaining: secondsRemaining, mode: mode),
            parkedCount: 0
        )

        do {
            current = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            AnalyticsErrorReporter.report(error, context: "liveactivity")
            Analytics.track(.liveActivityFailed(reason: error.localizedDescription))
            current = nil
        }
    }

    static func update(
        mode: TimerMode,
        secondsRemaining: Int,
        secondsElapsed: Int
    ) {
        guard let activity = current else { return }
        let now = Date()
        let endDate: Date? = mode == .countdown
            ? now.addingTimeInterval(TimeInterval(secondsRemaining))
            : nil

        let state = FlowStateActivityAttributes.State(
            secondsRemaining: secondsRemaining,
            secondsElapsed: secondsElapsed,
            startDate: activity.attributes.mode == .countup
                ? activity.content.state.startDate
                : now,
            endDate: endDate,
            phase: phaseFor(secondsRemaining: secondsRemaining, mode: mode),
            parkedCount: activity.content.state.parkedCount
        )

        _Concurrency.Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    /// Flip the activity into the `.complete` banner. Auto-ends after the
    /// linger window.
    static func setComplete() {
        guard let activity = current else { return }
        var state = activity.content.state
        state.phase = .complete

        _Concurrency.Task {
            await activity.update(ActivityContent(
                state: state,
                staleDate: Date().addingTimeInterval(postSessionLingerSeconds)
            ))
            try? await _Concurrency.Task.sleep(nanoseconds: UInt64(postSessionLingerSeconds * 1_000_000_000))
            await activity.end(nil, dismissalPolicy: .immediate)
            await MainActor.run { Self.current = nil }
        }
    }

    /// Flip into the `.parked` banner with the latest parked count. Auto-ends
    /// after the linger window.
    static func setParked(parkedCount: Int) {
        guard let activity = current else { return }
        var state = activity.content.state
        state.phase = .parked
        state.parkedCount = parkedCount

        _Concurrency.Task {
            await activity.update(ActivityContent(
                state: state,
                staleDate: Date().addingTimeInterval(postSessionLingerSeconds)
            ))
            try? await _Concurrency.Task.sleep(nanoseconds: UInt64(postSessionLingerSeconds * 1_000_000_000))
            await activity.end(nil, dismissalPolicy: .immediate)
            await MainActor.run { Self.current = nil }
        }
    }

    static func end() {
        guard let activity = current else { return }
        current = nil
        _Concurrency.Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: - Helpers

    /// Countdown ≤60s → `.lastMinute` (red pulse). Otherwise `.active`.
    /// Count-up sessions never enter the last-minute phase.
    private static func phaseFor(secondsRemaining: Int, mode: TimerMode) -> FlowStateActivityAttributes.Phase {
        guard mode == .countdown else { return .active }
        return secondsRemaining <= 60 && secondsRemaining > 0 ? .lastMinute : .active
    }
}
