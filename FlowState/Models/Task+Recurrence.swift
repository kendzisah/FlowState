import Foundation

extension Task {
    /// Returns the date+time at which this task occurs on `day`, if its recurrence rule
    /// covers that day. Returns nil for unscheduled tasks, days before the source date,
    /// or days that don't match the rule.
    ///
    /// The source day is always an occurrence (regardless of recurrence). For repeating
    /// tasks, this generates a "ghost" date for any future day that matches the rule —
    /// the calendar tab uses these to surface the task in future days without inserting
    /// duplicate rows in SwiftData.
    func occurrenceDate(on day: Date, calendar: Calendar = .current) -> Date? {
        guard let source = scheduledDate else { return nil }

        let sourceDay = calendar.startOfDay(for: source)
        let targetDay = calendar.startOfDay(for: day)

        // The source day always counts.
        if calendar.isDate(targetDay, inSameDayAs: sourceDay) { return source }

        // No recurrence → only the source day.
        guard recurrence != .none else { return nil }

        // Rules don't extend backwards.
        guard targetDay > sourceDay else { return nil }

        switch recurrence {
        case .none:
            return nil

        case .daily:
            return Self.applyTime(of: source, to: targetDay, calendar: calendar)

        case .weekdays:
            let weekday = calendar.component(.weekday, from: targetDay)
            // 1 = Sunday, 7 = Saturday in the Gregorian calendar.
            guard (2...6).contains(weekday) else { return nil }
            return Self.applyTime(of: source, to: targetDay, calendar: calendar)

        case .weekly:
            let sourceWD = calendar.component(.weekday, from: sourceDay)
            let targetWD = calendar.component(.weekday, from: targetDay)
            guard sourceWD == targetWD else { return nil }
            return Self.applyTime(of: source, to: targetDay, calendar: calendar)

        case .monthly:
            let sourceDOM = calendar.component(.day, from: sourceDay)
            let targetDOM = calendar.component(.day, from: targetDay)
            guard sourceDOM == targetDOM else { return nil }
            return Self.applyTime(of: source, to: targetDay, calendar: calendar)
        }
    }

    /// Returns true if this task's occurrence on the given day is a repeating "ghost"
    /// (not the original source day).
    func isGhostOccurrence(on day: Date, calendar: Calendar = .current) -> Bool {
        guard recurrence != .none, let source = scheduledDate else { return false }
        return !calendar.isDate(source, inSameDayAs: day)
    }

    private static func applyTime(of source: Date, to targetDay: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.hour, .minute, .second], from: source)
        return calendar.date(
            bySettingHour: comps.hour ?? 0,
            minute: comps.minute ?? 0,
            second: comps.second ?? 0,
            of: targetDay
        ) ?? targetDay
    }
}
