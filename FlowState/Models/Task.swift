import Foundation
import SwiftData

@Model
final class Task {
    var id: UUID
    var title: String
    var energyTagRaw: String
    var createdAt: Date
    var completedAt: Date?
    var isCompleted: Bool
    // PHASE B: var tagSource: String?   // "auto" / "manual"

    var energyTag: EnergyLevel {
        get { EnergyLevel(rawValue: energyTagRaw) ?? .steady }
        set {
            precondition(EnergyLevel.taskAssignable.contains(newValue),
                         "Foggy is a state, not a task tag")
            energyTagRaw = newValue.rawValue
        }
    }

    init(title: String, energyTag: EnergyLevel) {
        precondition(EnergyLevel.taskAssignable.contains(energyTag),
                     "Foggy is a state, not a task tag")
        self.id = UUID()
        self.title = title
        self.energyTagRaw = energyTag.rawValue
        self.createdAt = Date()
        self.isCompleted = false
    }
}
