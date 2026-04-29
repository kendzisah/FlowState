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

    public struct State: Codable, Hashable {
        var secondsRemaining: Int
        var secondsElapsed: Int
        var startDate: Date
        var endDate: Date?
    }

    var taskTitle: String
    var energyHex: String
    var mode: TimerKind
}
