// MUST stay byte-identical with FlowState/Widgets/Shared/WidgetSnapshot.swift
// (Codable round-trips JSON between the main app and the widget extension via
//  the shared App Group UserDefaults. Type identity isn't required, but the
//  field shapes and keys are — change both copies together.)
import Foundation

/// The single payload the main app writes to App Group UserDefaults after every
/// state mutation. Widgets read it via `WidgetSnapshotStore` and render off the
/// cached value. New fields go at the bottom and default to a sensible value
/// when missing so widgets bound to older snapshots don't crash.
nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {
    var writtenAt: Date
    var energy: SnapshotEnergy?           // nil when no check-in today
    var activeSession: SnapshotActiveSession?
    var recommendation: SnapshotTaskRow?  // top match for current energy
    var topTasks: [SnapshotTaskRow]       // up to 3 — fewer if list shorter
    var parked: SnapshotParked

    static let empty = WidgetSnapshot(
        writtenAt: .distantPast,
        energy: nil,
        activeSession: nil,
        recommendation: nil,
        topTasks: [],
        parked: SnapshotParked(count: 0, mostRecent: nil)
    )
}

nonisolated struct SnapshotEnergy: Codable, Equatable, Sendable {
    var level: String     // EnergyLevel.rawValue — foggy/scattered/steady/locked
    var hex: String       // 6-char hex (no #), matches EnergyLevel.hexString
    var setAt: Date
}

nonisolated struct SnapshotActiveSession: Codable, Equatable, Sendable {
    var taskID: String
    var title: String
    var energyHex: String
    var mode: String      // "countdown" | "countup" — matches TimerMode.rawValue
    var startedAt: Date
    var endsAt: Date?     // present only for countdown; nil = open-ended count-up
}

nonisolated struct SnapshotTaskRow: Codable, Equatable, Identifiable, Sendable {
    var id: String        // Task.id.uuidString
    var title: String
    var energyTag: String // EnergyLevel.rawValue
    var durationEstimateSeconds: Int?
}

nonisolated struct SnapshotParked: Codable, Equatable, Sendable {
    var count: Int
    var mostRecent: SnapshotParkedRow?
}

nonisolated struct SnapshotParkedRow: Codable, Equatable, Sendable {
    var id: String
    var title: String
    var parkedAt: Date
    var elapsedSeconds: Int
}
