import Foundation

enum DayTimeSlot: String, CaseIterable, Identifiable {
    case anytime, morning, afternoon, evening

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anytime:   return "Anytime"
        case .morning:   return "Morning"
        case .afternoon: return "Afternoon"
        case .evening:   return "Evening"
        }
    }

    var iconName: String {
        switch self {
        case .anytime:   return "clock"
        case .morning:   return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening:   return "moon.fill"
        }
    }

    var emptyStateCopy: String {
        switch self {
        case .anytime:   return "Anytime today works"
        case .morning:   return "What's on your morning list?"
        case .afternoon: return "What's happening today?"
        case .evening:   return "End the day your way"
        }
    }
}

/// A single item rendered on the Calendar tab. Discriminated union over
/// imported calendar events and scheduled tasks. Tasks carry the occurrence
/// date so a single recurring source can show up on any matching future day.
enum DayItem: Identifiable {
    case event(ImportedEvent)
    case task(Task, occurrenceDate: Date)

    /// Stable per-render id — ghosts of a recurring task get unique ids per occurrence.
    var id: String {
        switch self {
        case .event(let e):
            return "event-\(e.id.uuidString)"
        case .task(let t, let date):
            return "task-\(t.id.uuidString)-\(Int(date.timeIntervalSince1970))"
        }
    }

    var title: String {
        switch self {
        case .event(let e):     return e.title
        case .task(let t, _):   return t.title
        }
    }

    /// Sort key within a slot.
    var sortDate: Date {
        switch self {
        case .event(let e):     return e.startDate
        case .task(_, let d):   return d
        }
    }

    var energy: EnergyLevel? {
        switch self {
        case .event(let e):     return e.energy
        case .task(let t, _):   return t.energyTag
        }
    }

    var isAllDayLike: Bool {
        switch self {
        case .event(let e):
            return e.endDate.timeIntervalSince(e.startDate) >= 23 * 3600
        case .task:
            return false
        }
    }

    /// Icon shown in the leading column of `DayItemCard`. Recurring tasks
    /// (any occurrence, source or ghost) show the recurrence glyph.
    var sourceIcon: String {
        switch self {
        case .event: return "calendar"
        case .task(let t, _):
            return t.recurrence != .none ? "arrow.triangle.2.circlepath" : "checkmark.circle"
        }
    }
}

enum CalendarDayBuckets {
    /// Buckets the items belonging to `date` into the four day slots.
    /// Caller is responsible for filtering items down to the selected day.
    static func bucket(_ items: [DayItem], on date: Date, calendar: Calendar = .current) -> [DayTimeSlot: [DayItem]] {
        var result: [DayTimeSlot: [DayItem]] = [
            .anytime: [], .morning: [], .afternoon: [], .evening: []
        ]

        for item in items {
            let slot = slot(for: item, on: date, calendar: calendar)
            result[slot, default: []].append(item)
        }

        for key in result.keys {
            result[key]?.sort { $0.sortDate < $1.sortDate }
        }
        return result
    }

    static func slot(for item: DayItem, on date: Date, calendar: Calendar = .current) -> DayTimeSlot {
        // For events, the user-chosen display override wins so we don't have
        // to rewrite the imported `startDate`. Tasks are bucketed straight from
        // their `scheduledDate`, which the Move action updates in place.
        if case .event(let e) = item, let override = e.displaySlot {
            return override
        }

        if item.isAllDayLike { return .anytime }

        let hour = calendar.component(.hour, from: item.sortDate)
        switch hour {
        case 5..<12:  return .morning
        case 12..<17: return .afternoon
        case 17..<24: return .evening
        default:      return .anytime  // 0–4
        }
    }

    /// Returns true if `event` overlaps the calendar day containing `date`.
    static func event(_ event: ImportedEvent, overlaps date: Date, calendar: Calendar = .current) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        return event.startDate < dayEnd && event.endDate > dayStart
    }

}
