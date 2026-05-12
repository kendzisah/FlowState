import Foundation

enum Recurrence: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekdays, weekly, monthly

    var id: String { rawValue }

    /// Compact label for the chip (uppercase styling applied at the call site).
    var chipLabel: String {
        switch self {
        case .none:     return "No"
        case .daily:    return "Daily"
        case .weekdays: return "Weekdays"
        case .weekly:   return "Weekly"
        case .monthly:  return "Monthly"
        }
    }

    var menuLabel: String {
        switch self {
        case .none:     return "Don't repeat"
        case .daily:    return "Every day"
        case .weekdays: return "Every weekday"
        case .weekly:   return "Every week"
        case .monthly:  return "Every month"
        }
    }

    var iconName: String { "arrow.triangle.2.circlepath" }

    /// True if today is a day this recurrence rule fires, given a source day
    /// (used to anchor `.weekly` / `.monthly` patterns). The rule never fires
    /// on days strictly before the source. Shared between `RoutineGroup`'s
    /// scheduler and `Task+Recurrence`'s occurrence rendering.
    func coversToday(from source: Date, calendar: Calendar = .current) -> Bool {
        let sourceDay = calendar.startOfDay(for: source)
        let today = calendar.startOfDay(for: Date())

        if calendar.isDate(today, inSameDayAs: sourceDay) { return true }
        guard today > sourceDay else { return false }

        switch self {
        case .none:
            return false
        case .daily:
            return true
        case .weekdays:
            let weekday = calendar.component(.weekday, from: today)
            // 1 = Sunday, 7 = Saturday in Gregorian.
            return (2...6).contains(weekday)
        case .weekly:
            return calendar.component(.weekday, from: today)
                == calendar.component(.weekday, from: sourceDay)
        case .monthly:
            return calendar.component(.day, from: today)
                == calendar.component(.day, from: sourceDay)
        }
    }
}
