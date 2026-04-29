import Foundation
import SwiftData

@Model
final class ParkedTask {
    var id: UUID
    var taskId: UUID
    var taskTitle: String
    var elapsedSeconds: Int
    var parkedAt: Date

    init(taskId: UUID, taskTitle: String, elapsedSeconds: Int) {
        self.id = UUID()
        self.taskId = taskId
        self.taskTitle = taskTitle
        self.elapsedSeconds = elapsedSeconds
        self.parkedAt = Date()
    }
}
