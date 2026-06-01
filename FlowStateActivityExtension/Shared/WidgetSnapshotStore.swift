// MUST stay byte-identical with FlowState/Widgets/Shared/WidgetSnapshotStore.swift
import Foundation

/// Read/write the single `WidgetSnapshot` payload from the App Group UserDefaults
/// suite shared between the main app and the widget extension.
///
/// Read failures (missing key, decode error) return `WidgetSnapshot.empty` so
/// widgets always have something to render. Writes are best-effort — the
/// container's UserDefaults is reliable enough that we don't retry.
enum WidgetSnapshotStore {
    nonisolated static let appGroupID = "group.com.flocktechnologies.FlowState"
    nonisolated static let snapshotKey = "widget.snapshot.v1"

    private nonisolated static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private nonisolated static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private nonisolated static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    nonisolated static func read() -> WidgetSnapshot {
        guard let data = defaults?.data(forKey: snapshotKey),
              let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    nonisolated static func write(_ snapshot: WidgetSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults?.set(data, forKey: snapshotKey)
    }

    /// Used on sign-out to clear the previous user's tasks from widgets.
    nonisolated static func clear() {
        defaults?.removeObject(forKey: snapshotKey)
    }
}
