import Foundation

/// A single entry on the Schedule tab's vertical day timeline: either a timed
/// item (a calendar event or task occurrence) or a routine group placed at its
/// reminder time. Untimed items are handled separately by the "No set time"
/// tray, so they never become a `TimelineEntry`.
enum TimelineEntry: Identifiable {
    case item(DayItem)
    case routine(group: RoutineGroup, tasks: [Task], at: Date)

    var id: String {
        switch self {
        case .item(let item):
            return item.id
        case .routine(let group, _, let at):
            return "routine-\(group.id.uuidString)-\(Int(at.timeIntervalSince1970))"
        }
    }

    /// Chronological sort key / rail placement.
    var time: Date {
        switch self {
        case .item(let item):        return item.sortDate
        case .routine(_, _, let at): return at
        }
    }

    var hour: Int {
        Calendar.current.component(.hour, from: time)
    }
}

enum TimelineBuilder {
    /// Splits the day's items + routine groups into a chronological `timed`
    /// list and a separate `noSetTime` list.
    ///
    /// The untimed partition reuses `CalendarDayBuckets.slot(...) == .anytime`
    /// verbatim, so the tray is byte-for-byte equivalent to the old ANYTIME
    /// bucket (all-day events, `displaySlot == .anytime`, and items at hour
    /// 0–4) — this keeps `runAutoSortAnytime` semantics intact.
    static func build(
        items: [DayItem],
        groups: [(group: RoutineGroup, tasks: [Task])],
        on day: Date,
        calendar: Calendar = .current
    ) -> (timed: [TimelineEntry], noSetTime: [DayItem]) {
        var timed: [TimelineEntry] = []
        var noSetTime: [DayItem] = []

        for item in items {
            if CalendarDayBuckets.slot(for: item, on: day, calendar: calendar) == .anytime {
                noSetTime.append(item)
            } else {
                timed.append(.item(item))
            }
        }

        for entry in groups {
            let at = routineTime(for: entry.group, tasks: entry.tasks, on: day, calendar: calendar)
            timed.append(.routine(group: entry.group, tasks: entry.tasks, at: at))
        }

        timed.sort { lhs, rhs in
            if lhs.time != rhs.time { return lhs.time < rhs.time }
            return sortRank(lhs) < sortRank(rhs)
        }
        noSetTime.sort { $0.sortDate < $1.sortDate }

        return (timed, noSetTime)
    }

    /// Routine placement time: prefer the materialized task's real
    /// `scheduledDate` (which equals the notification fire time), otherwise the
    /// group's reminder time, otherwise the slot default.
    static func routineTime(
        for group: RoutineGroup,
        tasks: [Task],
        on day: Date,
        calendar: Calendar = .current
    ) -> Date {
        if let scheduled = tasks.compactMap(\.scheduledDate).min() {
            return scheduled
        }
        let hour = group.reminderHour ?? defaultHour(for: group.slot)
        let minute = group.reminderMinute ?? 0
        let dayStart = calendar.startOfDay(for: day)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) ?? dayStart
    }

    /// Slot fallback reminder hour, matching `RoutineScheduler` /
    /// `NotificationManager` (morning 8, afternoon 13, evening 20).
    static func defaultHour(for slot: RoutineSlot) -> Int {
        switch slot {
        case .morning:   return 8
        case .afternoon: return 13
        case .evening:   return 20
        }
    }

    /// Within the same minute, routines lead their hour, then items.
    private static func sortRank(_ entry: TimelineEntry) -> Int {
        switch entry {
        case .routine: return 0
        case .item:    return 1
        }
    }
}
