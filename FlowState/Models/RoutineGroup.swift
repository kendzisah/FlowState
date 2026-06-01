import Foundation
import SwiftData

/// User-named container for routines (e.g., "Morning routine", "Workout").
///
/// Each group has its own recurrence (so a "Weekday standup" group only fires
/// Mon–Fri) and an optional energy tag (display-only chip on the header — does
/// not change materialized Task energy, which stays `.steady` so routines
/// remain excluded from the energy-match sort).
///
/// Multiple groups can live within the same slot. The slot itself is still the
/// outer axis used to render groups under MORNING / AFTERNOON / EVENING headers.
@Model
final class RoutineGroup: Identifiable {
    var id: UUID
    var title: String
    var emoji: String?
    var slotRaw: String
    var recurrenceRaw: String
    /// Optional energy chip rendered on the group header. Children stay
    /// energy-neutral; this is purely visual for v1.
    var energyRaw: String?
    var userID: String?
    var createdAt: Date
    /// Mirror of RoutineTag.lastGeneratedDay at the group level; used as a
    /// cheap "we already processed this group today" guard during
    /// materialization.
    var lastGeneratedDay: Date?
    /// User-picked time-of-day for the routine reminder, stored as 24h
    /// hour + minute. When nil (legacy rows / groups created before this
    /// field existed), `RoutineScheduler` falls back to the slot's default
    /// hour (08/13/20).
    var reminderHour: Int?
    var reminderMinute: Int?

    var slot: RoutineSlot {
        get { RoutineSlot(rawValue: slotRaw) ?? .morning }
        set { slotRaw = newValue.rawValue }
    }

    var recurrence: Recurrence {
        get { Recurrence(rawValue: recurrenceRaw) ?? .daily }
        set { recurrenceRaw = newValue.rawValue }
    }

    var energy: EnergyLevel? {
        get { energyRaw.flatMap(EnergyLevel.init(rawValue:)) }
        set { energyRaw = newValue?.rawValue }
    }

    init(
        title: String,
        emoji: String? = nil,
        slot: RoutineSlot,
        recurrence: Recurrence = .daily,
        energy: EnergyLevel? = nil,
        userID: String? = nil,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.emoji = emoji
        self.slotRaw = slot.rawValue
        self.recurrenceRaw = (recurrence == .none ? Recurrence.daily : recurrence).rawValue
        self.energyRaw = energy?.rawValue
        self.userID = userID
        self.createdAt = Date()
        self.lastGeneratedDay = nil
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
    }
}
