// MUST stay byte-identical with FlowStateActivityExtension/FlowStateActivityAttributes.swift
// (Codable round-trips JSON between targets; Swift type identity is not required.)
import ActivityKit
import Foundation

struct FlowStateActivityAttributes: ActivityAttributes {
    public typealias ContentState = State

    public enum TimerKind: String, Codable, Hashable {
        case countdown
        case countup
    }

    /// What the Live Activity is currently showing.
    ///
    /// `.active` is the normal session display.
    /// `.lastMinute` triggers the gentle red pulse in the final 60s of a countdown.
    /// `.complete` shows the "Session complete" celebration banner with
    /// "Mark task done" / "Start another" affordances; auto-dismisses after 10s.
    /// `.parked` shows the Parked banner with Resume + View Parked Queue; also
    /// auto-dismisses after 10s.
    public enum Phase: String, Codable, Hashable {
        case active
        case lastMinute
        case complete
        case parked
    }

    public struct State: Codable, Hashable {
        var secondsRemaining: Int
        var secondsElapsed: Int
        var startDate: Date
        var endDate: Date?
        var phase: Phase
        var parkedCount: Int
    }

    var taskTitle: String
    var energyHex: String
    var mode: TimerKind
    /// Task UUID as string. Used by Park/Stop AppIntent buttons to reference
    /// the active task without round-tripping via App Group.
    var taskID: String
}
