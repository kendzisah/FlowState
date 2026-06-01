import Foundation
import Observation

enum RoutineSlot: String, Codable, CaseIterable, Identifiable {
    case morning, afternoon, evening
    var id: String { rawValue }

    /// Derive the slot from a 24h hour-of-day. Boundaries:
    ///   • 05:00–11:59 → morning
    ///   • 12:00–16:59 → afternoon
    ///   • 17:00–04:59 → evening
    /// Used by `EditRoutineGroupSheet` so the user only picks a time and the
    /// slot (used for sectioning in TaskListView) auto-classifies from it.
    static func from(hour: Int) -> RoutineSlot {
        switch hour {
        case 5...11:   return .morning
        case 12...16:  return .afternoon
        default:       return .evening
        }
    }

    /// Time-of-day emoji used as the default chip on new routine groups when
    /// the user hasn't typed their own. Matches the slot's vibe.
    var defaultEmoji: String {
        switch self {
        case .morning:   return "🌅"
        case .afternoon: return "☀️"
        case .evening:   return "🌙"
        }
    }
}

struct RoutineOption: Hashable, Identifiable {
    let id: String
    let emoji: String
    let label: String
}

struct DraftTask: Hashable, Identifiable {
    let id: UUID
    var title: String
    var category: String
    var suggestedEnergyRaw: String

    var suggestedEnergy: EnergyLevel? {
        let level = EnergyLevel(rawValue: suggestedEnergyRaw)
        return level.flatMap { EnergyLevel.taskAssignable.contains($0) ? $0 : nil }
    }
}

@Observable
@MainActor
final class OnboardingDraft {
    var marketingOptIn: Bool? = nil
    var primaryNeed: PrimaryNeed? = nil
    var neurodivergenceSelfId: NeurodivergenceSelfID? = nil

    var subscriptionStarted: Bool = false
    var notificationsGranted: Bool = false
    var calendarGranted: Bool = false

    var morningRoutines: Set<RoutineOption> = []
    var afternoonRoutines: Set<RoutineOption> = []
    var eveningRoutines: Set<RoutineOption> = []

    var weeklyIntentText: String = ""
    var generatedTasks: [DraftTask] = []
    var selectedTaskIDs: Set<UUID> = []

    var appleUserIdentifier: String? = nil
    var userEmail: String? = nil

    var allSelectedRoutines: [RoutineOption] {
        morningRoutines.sorted { $0.label < $1.label }
            + afternoonRoutines.sorted { $0.label < $1.label }
            + eveningRoutines.sorted { $0.label < $1.label }
    }

    var selectedTasks: [DraftTask] {
        generatedTasks.filter { selectedTaskIDs.contains($0.id) }
    }
}
