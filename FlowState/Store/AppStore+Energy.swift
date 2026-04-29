import SwiftUI

extension AppStore {
    func setEnergy(_ level: EnergyLevel) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            energyLevel = level
            energySetAt = Date()
            lastPromptAt = Date()
            peekList = false
        }
        fireEnergyHaptic(level)
    }

    func sortedTasks(_ tasks: [Task]) -> [Task] {
        let active = tasks.filter { !$0.isCompleted }
        guard let energy = energyLevel, energy != .foggy else {
            return active.sorted { $0.createdAt > $1.createdAt }
        }
        let matching = active
            .filter { $0.energyTag == energy }
            .sorted { $0.createdAt > $1.createdAt }
        let nonMatching = active
            .filter { $0.energyTag != energy }
            .sorted { $0.createdAt > $1.createdAt }
        return matching + nonMatching
    }

    func matchingCount(_ tasks: [Task]) -> Int {
        guard let energy = energyLevel, energy != .foggy else { return 0 }
        return tasks.filter { !$0.isCompleted && $0.energyTag == energy }.count
    }
}
