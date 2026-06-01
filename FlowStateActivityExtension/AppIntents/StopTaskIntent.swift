// MUST stay byte-identical with FlowState/Widgets/AppIntents/StopTaskIntent.swift
import AppIntents

/// Tapped from the Live Activity expanded view's Stop button. Treated as
/// "complete this task" (the same path as the in-app Complete button) since
/// "stop" without completion would lose the elapsed time — which the user
/// can already achieve via Park This.
struct StopTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop and complete task"
    static let description: IntentDescription = IntentDescription("Mark the current task complete and end the session.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}
    init(taskID: String) { self.taskID = taskID }

    func perform() async throws -> some IntentResult {
        PendingWidgetActionQueue.enqueue(.stopTask(taskID: taskID))
        return .result()
    }
}
