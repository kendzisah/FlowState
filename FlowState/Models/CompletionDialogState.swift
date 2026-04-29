import Foundation

struct CompletionDialogState: Equatable, Identifiable {
    let id: UUID
    let taskTitle: String
    let affirmation: String

    init(taskTitle: String, affirmation: String? = nil) {
        self.id = UUID()
        self.taskTitle = taskTitle
        self.affirmation = affirmation ?? AppStrings.completionAffirmations.randomElement()!
    }
}
