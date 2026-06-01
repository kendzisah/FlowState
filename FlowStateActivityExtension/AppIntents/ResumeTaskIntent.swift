// MUST stay byte-identical with FlowState/Widgets/AppIntents/ResumeTaskIntent.swift
import AppIntents

/// Tapped from the Small Parked Queue widget's Resume button. Opens the app
/// to the Timer view and resumes the parked task with its prior elapsed time.
struct ResumeTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume parked task"
    static let description: IntentDescription = IntentDescription("Pick up where you left off on a parked task.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Parked task ID")
    var parkedID: String

    init() {}
    init(parkedID: String) { self.parkedID = parkedID }

    func perform() async throws -> some IntentResult {
        PendingWidgetActionQueue.enqueue(.resumeParked(parkedID: parkedID))
        return .result()
    }
}
