// MUST stay byte-identical with FlowState/Widgets/Shared/WidgetSnapshot.swift
// (Codable round-trips JSON between the main app and the widget extension via
//  the shared App Group UserDefaults. Type identity isn't required, but the
//  field shapes and keys are — change both copies together.)
import Foundation

/// The single payload the main app writes to App Group UserDefaults after every
/// state mutation. Widgets read it via `WidgetSnapshotStore` and render off the
/// cached value. New fields go at the bottom and default to a sensible value
/// when missing so widgets bound to older snapshots don't crash.
struct WidgetSnapshot: Codable, Equatable {
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

struct SnapshotEnergy: Codable, Equatable {
    var level: String     // EnergyLevel.rawValue — foggy/scattered/steady/locked
    var hex: String       // 6-char hex (no #), matches EnergyLevel.hexString
    var setAt: Date
}

struct SnapshotActiveSession: Codable, Equatable {
    var taskID: String
    var title: String
    var energyHex: String
    var mode: String      // "countdown" | "countup" — matches TimerMode.rawValue
    var startedAt: Date
    var endsAt: Date?     // present only for countdown; nil = open-ended count-up
}

struct SnapshotTaskRow: Codable, Equatable, Identifiable {
    var id: String        // Task.id.uuidString
    var title: String
    var energyTag: String // EnergyLevel.rawValue
    var durationEstimateSeconds: Int?
}

struct SnapshotParked: Codable, Equatable {
    var count: Int
    var mostRecent: SnapshotParkedRow?
}

struct SnapshotParkedRow: Codable, Equatable {
    var id: String
    var title: String
    var parkedAt: Date
    var elapsedSeconds: Int
}
