// MUST stay byte-identical with FlowStateActivityExtension/Shared/PendingWidgetAction.swift
import Foundation

/// AppIntents triggered from widgets / Live Activity run in the extension
/// process and can't reach the main app's `AppStore` directly. Instead they
/// enqueue a typed action into App Group UserDefaults; the main app drains the
/// queue on next foreground (`PendingWidgetActionDrain.drain(...)`) and
/// performs the mutation against live state.
///
/// Why not perform the action in the extension via shared SwiftData? SwiftData
/// container sharing is fragile across processes and our existing snapshot
/// approach is already authoritative. A single drain on foreground keeps the
/// model simple and avoids racing with the main app's mutations.
enum PendingWidgetAction: Codable, Equatable {
    case startTask(taskID: String)
    case parkTask(taskID: String)
    case resumeParked(parkedID: String)
    case stopTask(taskID: String)
    case setEnergy(level: String)

    var debugDescription: String {
        switch self {
        case .startTask(let id):   return "startTask(\(id))"
        case .parkTask(let id):    return "parkTask(\(id))"
        case .resumeParked(let id):return "resumeParked(\(id))"
        case .stopTask(let id):    return "stopTask(\(id))"
        case .setEnergy(let l):    return "setEnergy(\(l))"
        }
    }
}

/// Append-only queue persisted in App Group UserDefaults. Widgets/intents
/// enqueue; the main app drains in order on foreground.
enum PendingWidgetActionQueue {
    nonisolated static let key = "widget.action.queue.v1"

    private nonisolated static var defaults: UserDefaults? {
        UserDefaults(suiteName: WidgetSnapshotStore.appGroupID)
    }

    private nonisolated static let encoder = JSONEncoder()
    private nonisolated static let decoder = JSONDecoder()

    nonisolated static func enqueue(_ action: PendingWidgetAction) {
        var current = readAll()
        current.append(action)
        guard let data = try? encoder.encode(current) else { return }
        defaults?.set(data, forKey: key)
    }

    nonisolated static func readAll() -> [PendingWidgetAction] {
        guard let data = defaults?.data(forKey: key),
              let actions = try? decoder.decode([PendingWidgetAction].self, from: data)
        else { return [] }
        return actions
    }

    /// Pop the whole queue and clear it. Called from the main app on foreground.
    nonisolated static func drain() -> [PendingWidgetAction] {
        let actions = readAll()
        defaults?.removeObject(forKey: key)
        return actions
    }
}
