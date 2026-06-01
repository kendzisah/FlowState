import Foundation
import SwiftData
import WidgetKit

/// Builds a `WidgetSnapshot` from current `AppStore` + `ModelContext` state
/// and writes it to the App Group UserDefaults so the widget extension can
/// render off the cached value. Also triggers a `WidgetCenter` reload so
/// timelines re-fetch immediately.
///
/// Call from any AppStore mutation that changes data the widgets surface:
/// timer events, energy check-ins, task creation/edit/delete, park/resume.
/// Cheap (no network, single in-memory pass + UserDefaults write); safe to
/// invoke from every relevant callsite.
@MainActor
enum WidgetSnapshotWriter {
    /// Build + write the snapshot. `context` is optional — when nil, only the
    /// AppStore-derived fields update and task lists go untouched. Pass a
    /// ModelContext from any AppStore action that already has one in scope.
    static func refresh(store: AppStore, context: ModelContext?) {
        let snapshot = build(store: store, context: context)
        WidgetSnapshotStore.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Drop the snapshot (e.g., on sign-out so the next user doesn't see the
    /// previous user's data in widgets).
    static func clear() {
        WidgetSnapshotStore.clear()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Build

    private static func build(store: AppStore, context: ModelContext?) -> WidgetSnapshot {
        let tasks = fetchActiveTasks(context: context)
        let sorted = store.sortedTasks(tasks)
        let topRows = Array(sorted.prefix(3).map(taskRow(_:)))
        return WidgetSnapshot(
            writtenAt: Date(),
            energy: energySnapshot(store: store),
            activeSession: activeSessionSnapshot(store: store),
            recommendation: topRows.first,
            topTasks: topRows,
            parked: parkedSnapshot(context: context)
        )
    }

    private static func energySnapshot(store: AppStore) -> SnapshotEnergy? {
        guard store.energyIsActiveToday, let level = store.energyLevel else { return nil }
        return SnapshotEnergy(
            level: level.rawValue,
            hex: level.hexString,
            setAt: store.energySetAt ?? Date()
        )
    }

    private static func activeSessionSnapshot(store: AppStore) -> SnapshotActiveSession? {
        guard store.timerRunning, let task = store.activeTask else { return nil }
        let energy = store.energyLevel ?? .steady
        let now = Date()
        let endsAt: Date? = store.timerMode == .countdown
            ? now.addingTimeInterval(TimeInterval(store.timerSecondsRemaining))
            : nil
        return SnapshotActiveSession(
            taskID: task.id.uuidString,
            title: task.title,
            energyHex: energy.hexString,
            mode: store.timerMode.rawValue,
            startedAt: now.addingTimeInterval(-TimeInterval(store.timerElapsedSeconds)),
            endsAt: endsAt
        )
    }

    private static func parkedSnapshot(context: ModelContext?) -> SnapshotParked {
        guard let context else { return SnapshotParked(count: 0, mostRecent: nil) }
        let descriptor = FetchDescriptor<ParkedTask>(
            sortBy: [SortDescriptor(\.parkedAt, order: .reverse)]
        )
        let parked = (try? context.fetch(descriptor)) ?? []
        let mostRecent = parked.first.map {
            SnapshotParkedRow(
                id: $0.id.uuidString,
                title: $0.taskTitle,
                parkedAt: $0.parkedAt,
                elapsedSeconds: $0.elapsedSeconds
            )
        }
        return SnapshotParked(count: parked.count, mostRecent: mostRecent)
    }

    private static func fetchActiveTasks(context: ModelContext?) -> [Task] {
        guard let context else { return [] }
        let descriptor = FetchDescriptor<Task>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func taskRow(_ task: Task) -> SnapshotTaskRow {
        SnapshotTaskRow(
            id: task.id.uuidString,
            title: task.title,
            energyTag: task.energyTag.rawValue,
            durationEstimateSeconds: task.energyTag.defaultDurationSeconds
        )
    }
}

