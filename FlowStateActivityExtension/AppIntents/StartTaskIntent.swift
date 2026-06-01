// MUST stay byte-identical with FlowState/Widgets/AppIntents/StartTaskIntent.swift
import AppIntents
import WidgetKit

/// Tapped from the Small Recommendation widget or Medium Top-3 widget.
/// Opens the app and starts the focus session for the given task ID. The
/// intent enqueues a pending action; the app processes it on foreground.
struct StartTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Start task"
    static let description: IntentDescription = IntentDescription("Begin a focus session for the selected task.")

    /// Opening the app is intentional — the user wants to see the timer, and
    /// AppStore mutations are MainActor-bound to the app process.
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}
    init(taskID: String) { self.taskID = taskID }

    func perform() async throws -> some IntentResult {
        PendingWidgetActionQueue.enqueue(.startTask(taskID: taskID))
        return .result()
    }
}
