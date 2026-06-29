import Foundation
import SwiftData

extension ModelContext {
    /// Save + sync wrapper for any user-data mutation. Call this in place of
    /// `try? context.save()` wherever a Task/ParkedTask/ImportedEvent is
    /// inserted, updated, or deleted.
    ///
    /// It walks the pending change sets, stamps inserted/changed rows as
    /// `userID = <current user>` (if missing) and `updatedAt = now`,
    /// `syncedAt = nil`. Deleted rows have their IDs captured so the matching
    /// server rows can be removed too. Then it saves and triggers a sync pass
    /// in the background — the user doesn't have to wait.
    func saveAndSync() {
        let now = Date()
        let userID = AuthManager.shared.currentUserID

        for case let task as Task in insertedModelsArray + changedModelsArray {
            if task.userID == nil, let userID { task.userID = userID }
            task.updatedAt = now
            task.syncedAt = nil
        }
        for case let parked as ParkedTask in insertedModelsArray + changedModelsArray {
            if parked.userID == nil, let userID { parked.userID = userID }
            parked.updatedAt = now
            parked.syncedAt = nil
        }
        for case let event as ImportedEvent in insertedModelsArray + changedModelsArray {
            if event.userID == nil, let userID { event.userID = userID }
            event.updatedAt = now
            event.syncedAt = nil
        }

        // Capture deletions before save() clears them.
        var deletedTaskIDs:   [UUID] = []
        var deletedParkedIDs: [UUID] = []
        var deletedEventIDs:  [UUID] = []
        for case let task   as Task           in deletedModelsArray { deletedTaskIDs.append(task.id) }
        for case let parked as ParkedTask     in deletedModelsArray { deletedParkedIDs.append(parked.id) }
        for case let event  as ImportedEvent  in deletedModelsArray { deletedEventIDs.append(event.id) }

        try? save()

        // Fire-and-forget server deletes + push pass.
        if !deletedTaskIDs.isEmpty {
            for id in deletedTaskIDs { SyncEngine.shared.deleteRemote(Task.self, id: id) }
        }
        if !deletedParkedIDs.isEmpty {
            for id in deletedParkedIDs { SyncEngine.shared.deleteRemote(ParkedTask.self, id: id) }
        }
        if !deletedEventIDs.isEmpty {
            for id in deletedEventIDs { SyncEngine.shared.deleteRemote(ImportedEvent.self, id: id) }
        }

        if userID != nil {
            _Concurrency.Task { @MainActor [self] in
                await SyncEngine.shared.runFullSync(context: self)
            }
        }

        // Refresh widgets after every persisted mutation so the home-screen
        // surfaces (Top 3, Parked Queue, Recommendation) reflect the latest
        // task list within a second of the change.
        if let appStore = AppStore.activeInstanceForWidgetRefresh {
            WidgetSnapshotWriter.refresh(store: appStore, context: self)
        }

        // Rebuild notifications that depend on tasks/events: per-task reminders,
        // the morning/afternoon/evening window digests, and upcoming-event
        // reminders. Cheap drop-and-rebuild. Routine + energy reminders refresh
        // from their own paths (sheet saves / foreground).
        NotificationManager.refreshAllTaskReminders(context: self)
        NotificationManager.refreshWindowReminders(context: self)
        NotificationManager.refreshAllEventReminders(context: self)
    }
}
