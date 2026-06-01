import Foundation
import SwiftData

/// Maps `flowstate://` URLs into `AppStore` mutations. Also drains pending
/// widget actions enqueued from AppIntent buttons (Park/Stop/Resume/Start/
/// SetEnergy) — those run in the widget extension process and can't touch
/// AppStore directly, so they queue and the router picks them up on next
/// app foreground / launch.
@MainActor
enum DeepLinkRouter {
    /// Handle a URL delivered via `.onOpenURL`. Returns true if the URL was
    /// routed; false means the URL didn't match any known route and the caller
    /// can decide whether to log it.
    @discardableResult
    static func handle(
        _ url: URL,
        store: AppStore,
        context: ModelContext,
        allTasks: [Task] = []
    ) -> Bool {
        guard let route = DeepLinkRoute(url: url) else { return false }
        apply(route, store: store, context: context, allTasks: allTasks)
        return true
    }

    /// Pop and apply every queued pending action. Call on `.task { }` at app
    /// launch and on foreground transitions. Safe to call repeatedly — empty
    /// queue is a no-op.
    static func drainPendingActions(
        store: AppStore,
        context: ModelContext,
        allTasks: [Task]
    ) {
        let actions = PendingWidgetActionQueue.drain()
        for action in actions {
            apply(action, store: store, context: context, allTasks: allTasks)
        }
    }

    // MARK: - Apply

    private static func apply(
        _ route: DeepLinkRoute,
        store: AppStore,
        context: ModelContext,
        allTasks: [Task]
    ) {
        switch route {
        case .timer:
            // No-op routing into timer is the default when a session is
            // active; if not, fall through to home (router does nothing).
            break

        case .checkin:
            store.energyLevel = nil
            store.energySetAt = nil

        case .checkinWithLevel(let raw):
            if let level = EnergyLevel(rawValue: raw) {
                store.setEnergy(level, source: "deeplink")
            }

        case .task(let id):
            if let task = allTasks.first(where: { $0.id == id }), !task.isCompleted {
                store.startTask(task)
            }

        case .parked:
            // Selection of the Parked Queue surface — the app's existing nav
            // handles which tab/view to show; routing just opens the app.
            break

        case .parkedLearn:
            // Same — opens app; the calling UI shows the explainer sheet.
            break

        case .addTask:
            store.showAddTask = true

        case .routine:
            // No dedicated routine-detail view yet — opening the app to
            // today (the current default route when no other state forces a
            // different one) is the V1 behaviour. The route exists so future
            // navigation can change without retraining users on a new URL.
            break
        }

        Analytics.track(.deepLinkOpened(scheme: DeepLinkRoute.scheme, source: "url"))
    }

    private static func apply(
        _ action: PendingWidgetAction,
        store: AppStore,
        context: ModelContext,
        allTasks: [Task]
    ) {
        switch action {
        case .startTask(let id):
            if let uuid = UUID(uuidString: id),
               let task = allTasks.first(where: { $0.id == uuid }),
               !task.isCompleted {
                store.startTask(task)
            }

        case .parkTask:
            // The active task is whatever AppStore.activeTask currently is —
            // park doesn't need an ID round-trip because there's only ever
            // one active session.
            store.parkTask(context: context)

        case .resumeParked(let id):
            guard let uuid = UUID(uuidString: id) else { return }
            let parkedDescriptor = FetchDescriptor<ParkedTask>(
                predicate: #Predicate { $0.id == uuid }
            )
            if let parked = (try? context.fetch(parkedDescriptor))?.first {
                store.resumeParked(parked, allTasks: allTasks, context: context)
            }

        case .stopTask:
            if let task = store.activeTask {
                store.completeTask(task, context: context)
            }

        case .setEnergy(let raw):
            if let level = EnergyLevel(rawValue: raw) {
                store.setEnergy(level, source: "widget")
            }
        }

        Analytics.track(.deepLinkOpened(scheme: "widget.intent", source: "appintent"))
    }
}
