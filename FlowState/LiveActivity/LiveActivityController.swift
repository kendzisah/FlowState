import ActivityKit
import Foundation

@MainActor
enum LiveActivityController {
    private static var current: Activity<FlowStateActivityAttributes>?

    static func start(
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
            mode: mode == .countdown ? .countdown : .countup
        )
        let state = FlowStateActivityAttributes.State(
            secondsRemaining: secondsRemaining,
            secondsElapsed: secondsElapsed,
            startDate: now,
            endDate: endDate
        )

        do {
            current = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
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
                ? (activity.content.state.startDate)
                : now,
            endDate: endDate
        )

        _Concurrency.Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    static func end() {
        guard let activity = current else { return }
        current = nil
        _Concurrency.Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
