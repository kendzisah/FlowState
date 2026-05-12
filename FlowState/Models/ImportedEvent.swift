import Foundation
import SwiftData

@Model
final class ImportedEvent {
    var id: UUID
    var externalIdentifier: String
    var title: String
    var startDate: Date
    var endDate: Date
    var calendarTitle: String?
    var importedAt: Date

    /// Energy classification. Nil = not yet classified by AI/heuristic.
    /// Stored as raw string so SwiftData migration is trivial.
    var energyRaw: String?

    /// True once the user has manually picked an energy. AI re-runs skip these.
    var userOverrideEnergy: Bool = false

    /// User-chosen time-of-day bucket override for the Calendar tab. When set,
    /// the card appears in this slot regardless of `startDate`. Nil means
    /// "bucket by the actual event time". We never touch `startDate` so the
    /// underlying calendar truth stays intact across re-imports.
    var displaySlotRaw: String? = nil

    var displaySlot: DayTimeSlot? {
        get { displaySlotRaw.flatMap { DayTimeSlot(rawValue: $0) } }
        set { displaySlotRaw = newValue?.rawValue }
    }

    // MARK: - Sync fields

    var userID: String?
    var updatedAt: Date?
    var syncedAt: Date?

    func markDirty() {
        updatedAt = Date()
        syncedAt = nil
    }

    var energy: EnergyLevel? {
        get { energyRaw.flatMap { EnergyLevel(rawValue: $0) } }
        set {
            // Events are never "foggy" — that's a user state, not a task state.
            guard let v = newValue, EnergyLevel.taskAssignable.contains(v) else {
                energyRaw = nil
                return
            }
            energyRaw = v.rawValue
        }
    }

    init(externalIdentifier: String, title: String, startDate: Date, endDate: Date, calendarTitle: String? = nil) {
        self.id = UUID()
        self.externalIdentifier = externalIdentifier
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.calendarTitle = calendarTitle
        self.importedAt = Date()
        self.energyRaw = nil
        self.userOverrideEnergy = false
    }
}
