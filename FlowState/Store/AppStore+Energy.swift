import SwiftUI

extension AppStore {
    func setEnergy(_ level: EnergyLevel, source: String = "checkin") {
        if let prev = energyLevel, prev != level {
            Analytics.track(.energyChanged(from: prev.rawValue, to: level.rawValue, source: source))
        } else if energyLevel == nil {
            Analytics.track(.energySet(level: level.rawValue, source: source))
        }
        if level == .foggy {
            Analytics.track(.foggyRestChosen)
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            energyLevel = level
            energySetAt = Date()
            lastPromptAt = Date()
            peekList = false
        }
        fireEnergyHaptic(level)
        WidgetSnapshotWriter.refresh(store: self, context: nil)
    }

    /// Energy-matched sort for the regular task list. Routine tasks are
    /// excluded — they're rendered in their own slot groups (energy-neutral)
    /// above this list.
    func sortedTasks(_ tasks: [Task]) -> [Task] {
        let active = tasks.filter { !$0.isCompleted && !$0.isRoutine }
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
        return tasks.filter { !$0.isCompleted && !$0.isRoutine && $0.energyTag == energy }.count
    }
}
