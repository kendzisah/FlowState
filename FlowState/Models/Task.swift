import Foundation
import SwiftData

@Model
final class Task: Identifiable {
    var id: UUID
    var title: String
    var energyTagRaw: String
    var createdAt: Date
    var completedAt: Date?
    var isCompleted: Bool
    /// When set, this task surfaces in the Calendar tab on the matching day.
    var scheduledDate: Date?
    /// True when `scheduledDate` carries a clock time the user committed to (an
    /// appointment-like slot) vs. a "sometime today" placement. Drives the home
    /// FixedPointsRail (anchored) vs. energy lanes (flexible) split. Existing rows
    /// default to `false` (flexible), so the migration is a no-op.
    var isAnchored: Bool = false
    /// User-chosen recurrence intent. Persisted only; instance materialization is a follow-up.
    var recurrenceRaw: String?

    // MARK: - Sync fields

    /// Supabase user UUID that owns this row. Nil for legacy/orphan rows from
    /// before the auth gate landed; SyncEngine claims those on sign-in.
    var userID: String?
    /// Last local mutation. Sync compares this to `syncedAt` to find dirty rows.
    var updatedAt: Date?
    /// Last successful push to Supabase. Nil means "needs push".
    var syncedAt: Date?

    // MARK: - Routine metadata (local-only)

    /// True when this Task was materialized from a `RoutineTag`. Routine tasks
    /// render in their own collapsible slot groups above the regular list and
    /// are energy-neutral (the energy filter and Match banner ignore them).
    var isRoutine: Bool = false
    /// Slot the source routine belongs to. Mirrors `RoutineSlot.rawValue`
    /// ("morning" / "afternoon" / "evening"). Only meaningful when
    /// `isRoutine` is true.
    var routineSlot: String?
    /// `RoutineTag.id` this task was materialized from. `RoutineScheduler`
    /// uses this to find an uncompleted prior instance and roll it forward
    /// to today rather than inserting a duplicate.
    var sourceRoutineID: UUID?

    var recurrence: Recurrence {
        get { Recurrence(rawValue: recurrenceRaw ?? "") ?? .none }
        set { recurrenceRaw = newValue == .none ? nil : newValue.rawValue }
    }

    var energyTag: EnergyLevel {
        get { EnergyLevel(rawValue: energyTagRaw) ?? .steady }
        set {
            precondition(EnergyLevel.taskAssignable.contains(newValue),
                         "Foggy is a state, not a task tag")
            energyTagRaw = newValue.rawValue
        }
    }

    init(title: String, energyTag: EnergyLevel, userID: String? = nil) {
        precondition(EnergyLevel.taskAssignable.contains(energyTag),
                     "Foggy is a state, not a task tag")
        self.id = UUID()
        self.title = title
        self.energyTagRaw = energyTag.rawValue
        self.createdAt = Date()
        self.isCompleted = false
        self.userID = userID
        self.updatedAt = Date()
        self.syncedAt = nil
    }

    /// Stamps `updatedAt = now` and clears `syncedAt`. Call this immediately
    /// before `context.save()` for any mutation you want sync to pick up.
    func markDirty() {
        updatedAt = Date()
        syncedAt = nil
    }
}
