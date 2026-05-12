import Foundation
import SwiftData

@Model
final class ParkedTask {
    var id: UUID
    var taskId: UUID
    var taskTitle: String
    var elapsedSeconds: Int
    var parkedAt: Date

    // MARK: - Sync fields

    var userID: String?
    var updatedAt: Date?
    var syncedAt: Date?

    init(taskId: UUID, taskTitle: String, elapsedSeconds: Int, userID: String? = nil) {
        self.id = UUID()
        self.taskId = taskId
        self.taskTitle = taskTitle
        self.elapsedSeconds = elapsedSeconds
        self.parkedAt = Date()
        self.userID = userID
        self.updatedAt = Date()
        self.syncedAt = nil
    }

    func markDirty() {
        updatedAt = Date()
        syncedAt = nil
    }
}
