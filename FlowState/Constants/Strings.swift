enum AppStrings {
    static let completionAffirmations: [String] = [
        "Your brain showed up. That's the hard part.",
        "Done. One less thing living rent-free up there.",
        "Real work, really finished. Take a breath.",
        "You started and you finished — proud of you.",
        "That one's off the list. Every size counts.",
        "Momentum is a gift. You just gave yourself one.",
        "Whatever it took to finish that, you did it.",
        "Another win. Your future self says thanks."
    ]

    static let foggyMicroActions: [String] = [
        "Drink a glass of water.",
        "Take five slow breaths.",
        "Stand up. Stretch once.",
        "Open a window. Look outside for a minute.",
        "Eat something small.",
        "Put on something comfortable.",
        "Step outside for two minutes.",
        "Set your phone down. Five minutes of nothing.",
        "Lie on the floor. Yes, really.",
        "Splash cold water on your face."
    ]

    static let checkInPrompt = "What's your energy\nright now?"

    static let restHeadline = "Low battery mode."
    static let restSubhead = "Do one gentle thing.\nThat's the whole list."
    static let restTryThisLabel = "TRY THIS"
    static let restPeekCTA = "Show me my list anyway"
    static let restPeekFooter = "No pressure. Come back whenever."

    static let switcherTitle = "How's your energy?"
    static let switcherSubtitle = "Shift your focus level — the list will re-sort."
    static let switcherCurrentBadge = "CURRENT"

    static let durationPickerTitle = "How long?"
    static let durationPickerSubtitle = "Pre-filled from your energy. Change anytime."
    static let durationPickerSuggested = "SUGGESTED"
    static let durationNoCap = "No cap"

    static let timerFocusLabel = "FOCUS SESSION"
    static let timerHijackPrompt = "brain hijack?"
    static let timerParkAction = "Park This"
    static let timerDoneAction = "Done"

    static let completionPillLabel = "COMPLETE"
    static let completionDismiss = "Keep going"

    static let parkedEmptyState = "Nothing parked"
    static let parkedTabLabel = "Parked"
    static let tasksTabLabel = "Tasks"

    static let addTaskTitlePlaceholder = "What's on your mind?"
    static let addTaskSaveAction = "Add"

    static let notificationCompletionTitle = "Session complete"
    static let notificationCompletionBody = "Take a breath. You earned it."

    static func matchBanner(count: Int, energyLabel: String) -> String {
        let task = count == 1 ? "task matches" : "tasks match"
        return "\(count) \(task) your \(energyLabel) energy right now"
    }
}
