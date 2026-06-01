import AppIntents

/// Tapped from the Live Activity expanded view's Park This button. Enqueues
/// the action; the app drains the queue on next foreground.
///
/// `openAppWhenRun = false` is the V2 goal (so the Live Activity tap feels
/// instant and the user doesn't get yanked into the app). V1 opens the app
/// since `AppStore.parkTask` is `@MainActor` and the SwiftData context lives
/// there. Re-evaluate when LiveActivityIntent migration ships.
struct ParkTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Park task"
    static let description: IntentDescription = IntentDescription("Save the current session for later and return to the task list.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}
    init(taskID: String) { self.taskID = taskID }

    func perform() async throws -> some IntentResult {
        PendingWidgetActionQueue.enqueue(.parkTask(taskID: taskID))
        return .result()
    }
}
