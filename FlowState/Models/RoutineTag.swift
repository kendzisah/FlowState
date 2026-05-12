import Foundation
import SwiftData

@Model
final class RoutineTag: Identifiable {
    var id: UUID
    var emoji: String
    var label: String
    var slotRaw: String
    var createdAt: Date
    /// Start-of-day for the last day a Task was materialized from this routine.
    /// `RoutineScheduler` uses this to dedupe so each routine only creates one
    /// Task per day. Nil for routines that have never been materialized yet.
    var lastGeneratedDay: Date?
    /// Supabase user UUID that owns this routine. Nil for rows created before
    /// this field existed; `RoutineScheduler` treats those as belonging to the
    /// current user (claim-on-first-use) so legacy data still materializes.
    var userID: String?
    /// Parent `RoutineGroup.id`. Nil for legacy rows created before groups
    /// existed; `RoutineScheduler` adopts those into a default per-slot group
    /// on the next foreground.
    var groupID: UUID?

    var slot: RoutineSlot {
        get { RoutineSlot(rawValue: slotRaw) ?? .morning }
        set { slotRaw = newValue.rawValue }
    }

    init(
        emoji: String,
        label: String,
        slot: RoutineSlot,
        userID: String? = nil,
        groupID: UUID? = nil
    ) {
        self.id = UUID()
        self.emoji = emoji
        self.label = label
        self.slotRaw = slot.rawValue
        self.createdAt = Date()
        self.lastGeneratedDay = nil
        self.userID = userID
        self.groupID = groupID
    }
}
