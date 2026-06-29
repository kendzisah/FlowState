import Foundation
import SwiftData
@preconcurrency import UserNotifications

/// Owns every `UNUserNotificationCenter` interaction.
///
/// Two notification types ship today:
///   • **Timer complete** — single one-shot per active session; identifier
///     `timerCompleteIdentifier`.
///   • **Routine reminder** — daily / weekly / weekdays / monthly recurring
///     reminders, one (or five for weekdays) per `RoutineGroup` with a set
///     `reminderHour`; identifier prefix `routinePrefix`.
///
/// Tap routing for both types goes through `NotificationDelegate`, which
/// reads `userInfo["deep_link"]` and bridges into the SwiftUI scene via
/// `Notification.Name.flowStateDeepLink`.
@MainActor
enum NotificationManager {
    // MARK: - Identifiers

    nonisolated private static let timerCompleteIdentifier = "com.flocktechnologies.FlowState.timerComplete"
    nonisolated private static let routinePrefix = "routine."
    nonisolated private static let taskPrefix = "task."
    nonisolated private static let energyPrefix = "energy."
    nonisolated private static let windowPrefix = "window."
    nonisolated private static let eventPrefix = "event."

    /// iOS limits 64 pending notifications app-wide. We split the budget:
    ///   • 1 timer-complete
    ///   • 3 energy check-in prompts (fixed daily times)
    ///   • 3 time-window reminders (morning / afternoon / evening)
    ///   • up to 22 routine reminders
    ///   • up to 20 scheduled-task reminders
    ///   • up to 12 upcoming-event reminders
    ///   • 3 slot buffer
    private static let routineReminderCap = 22
    private static let taskReminderCap = 20
    private static let eventReminderCap = 12

    /// Fixed times of day for the "what's your energy now?" nudge. Spread
    /// across the day so the user re-checks as their focus drifts. Staggered
    /// off the window-reminder hours (9/13/18) to avoid banner pile-ups.
    nonisolated private static let energyCheckInTimes: [(hour: Int, minute: Int)] = [
        (10, 30), (15, 30), (20, 30)
    ]

    // MARK: - Permission

    private static var requestedAuth = false

    static func requestAuthorizationIfNeeded() async {
        guard !requestedAuth else { return }
        requestedAuth = true
        Analytics.track(.notificationsPermissionRequested)
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        Analytics.track(.notificationsPermissionResult(granted: granted))
    }

    // MARK: - Refresh-all entry point

    /// Single rebuild of every recurring/scheduled notification surface.
    /// Each member is an idempotent drop-and-rebuild, so calling this on launch,
    /// every foreground, and after any data mutation keeps pending notifications
    /// in lockstep with current state. Cheap (in-memory, no network).
    static func refreshAll(context: ModelContext) {
        refreshAllRoutineReminders(context: context)
        refreshAllTaskReminders(context: context)
        refreshAllEventReminders(context: context)
        refreshWindowReminders(context: context)
        refreshEnergyCheckInReminders()
    }

    // MARK: - Timer complete

    static func scheduleCompletion(after seconds: Int) {
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = AppStrings.notificationCompletionTitle
        content.body  = AppStrings.notificationCompletionBody
        content.sound = .default
        // Tap → deep-link to the timer view via NotificationDelegate.
        content.userInfo = [
            "type": "timer_complete",
            "deep_link": "flowstate://timer",
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: timerCompleteIdentifier, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [timerCompleteIdentifier])
        center.add(request)
    }

    static func cancelCompletion() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timerCompleteIdentifier])
    }

    // MARK: - Routine reminders

    /// Drop every `routine.*` notification and rebuild from the current user's
    /// `RoutineGroup`s. Cheap (no network, in-memory only) so it's safe to
    /// call from every routine mutation + foreground transition. Idempotent.
    ///
    /// Bails when notifications are globally disabled (per-user setting or
    /// signed-out state), leaving zero pending routine reminders.
    static func refreshAllRoutineReminders(context: ModelContext) {
        cancelAllRoutineReminders()

        guard let store = AppStore.activeInstanceForWidgetRefresh,
              store.notificationsEnabled,
              let userID = AuthManager.shared.currentUserID
        else { return }

        var descriptor = FetchDescriptor<RoutineGroup>(
            predicate: #Predicate { g in
                g.userID == userID || g.userID == nil
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 256
        let groups = (try? context.fetch(descriptor)) ?? []

        // Build requests in order; stop once we'd exceed the per-app slot
        // budget. Older groups win (established habits keep firing).
        var pending: [UNNotificationRequest] = []
        var droppedGroupCount = 0
        for group in groups {
            let requests = buildRequests(for: group, context: context)
            if requests.isEmpty { continue }
            if pending.count + requests.count > routineReminderCap {
                droppedGroupCount += 1
                continue
            }
            pending.append(contentsOf: requests)
        }

        if droppedGroupCount > 0 {
            Analytics.track(.routineRemindersCapped(droppedCount: droppedGroupCount))
        }

        let center = UNUserNotificationCenter.current()
        for request in pending {
            center.add(request) { error in
                guard let error else { return }
                // Hop back onto MainActor to call the reporter.
                _Concurrency.Task { @MainActor in
                    AnalyticsErrorReporter.report(error, context: "notifications.routine.add")
                }
            }
        }
    }

    static func cancelAllRoutineReminders() {
        cancelByPrefix(routinePrefix)
    }

    /// Remove every pending notification whose identifier starts with `prefix`.
    /// The completion fires on a private queue — re-fetch the singleton inside
    /// instead of capturing `center` (UNUserNotificationCenter isn't Sendable;
    /// strict concurrency flags the capture).
    nonisolated private static func cancelByPrefix(_ prefix: String) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            guard !ids.isEmpty else { return }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Task reminders

    /// Drop every `task.*` notification and rebuild from the current user's
    /// scheduled, non-completed, non-routine `Task`s.
    ///
    /// Routine-derived tasks (`isRoutine == true`) are deliberately excluded —
    /// the parent `RoutineGroup`'s reminder already covers them, and firing
    /// two banners for the same instance is annoying.
    static func refreshAllTaskReminders(context: ModelContext) {
        cancelAllTaskReminders()

        guard let store = AppStore.activeInstanceForWidgetRefresh,
              store.notificationsEnabled,
              AuthManager.shared.currentUserID != nil
        else { return }

        var descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { task in
                task.isCompleted == false
                    && task.isRoutine == false
                    && task.scheduledDate != nil
            },
            sortBy: [SortDescriptor(\.scheduledDate, order: .forward)]
        )
        descriptor.fetchLimit = 256
        let tasks = (try? context.fetch(descriptor)) ?? []

        var pending: [UNNotificationRequest] = []
        var droppedTaskCount = 0
        for task in tasks {
            let requests = buildRequests(for: task)
            if requests.isEmpty { continue }
            if pending.count + requests.count > taskReminderCap {
                droppedTaskCount += 1
                continue
            }
            pending.append(contentsOf: requests)
        }

        if droppedTaskCount > 0 {
            Analytics.track(.taskRemindersCapped(droppedCount: droppedTaskCount))
        }

        let center = UNUserNotificationCenter.current()
        for request in pending {
            center.add(request) { error in
                guard let error else { return }
                _Concurrency.Task { @MainActor in
                    AnalyticsErrorReporter.report(error, context: "notifications.task.add")
                }
            }
        }
    }

    static func cancelAllTaskReminders() {
        cancelByPrefix(taskPrefix)
    }

    // MARK: - Energy check-in prompts

    /// Schedule the fixed daily "what's your energy now?" nudges. Repeating
    /// calendar triggers — durable without app opens. Tap deep-links to the
    /// check-in flow (`flowstate://checkin`), which clears today's energy so
    /// the user re-picks.
    static func refreshEnergyCheckInReminders() {
        cancelByPrefix(energyPrefix)

        guard let store = AppStore.activeInstanceForWidgetRefresh,
              store.notificationsEnabled,
              AuthManager.shared.currentUserID != nil
        else { return }

        let center = UNUserNotificationCenter.current()
        for (index, time) in energyCheckInTimes.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = AppStrings.notificationEnergyCheckInTitle
            content.body = AppStrings.notificationEnergyCheckInBody
            content.sound = .default
            content.userInfo = [
                "type": "energy_checkin",
                "deep_link": "flowstate://checkin",
            ]
            content.threadIdentifier = "energy"

            var comps = DateComponents()
            comps.hour = time.hour
            comps.minute = time.minute
            let req = request(id: "\(energyPrefix)\(index)", comps: comps, content: content, repeats: true)
            center.add(req) { error in
                guard let error else { return }
                _Concurrency.Task { @MainActor in
                    AnalyticsErrorReporter.report(error, context: "notifications.energy.add")
                }
            }
        }
    }

    static func cancelAllEnergyCheckInReminders() {
        cancelByPrefix(energyPrefix)
    }

    // MARK: - Time-window reminders

    /// One reminder per time-of-day window (morning / afternoon / evening),
    /// nudging the user to do the (non-routine) tasks scheduled in that window.
    /// Only windows that actually have a task today get a reminder, so we never
    /// nag about an empty window. Daily-repeating for durability; the body is
    /// rebuilt from the live task list on every refresh.
    ///
    /// Routine tasks are intentionally excluded — their parent `RoutineGroup`
    /// reminder already covers them.
    static func refreshWindowReminders(context: ModelContext) {
        cancelByPrefix(windowPrefix)

        guard let store = AppStore.activeInstanceForWidgetRefresh,
              store.notificationsEnabled,
              AuthManager.shared.currentUserID != nil
        else { return }

        var descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { task in
                task.isCompleted == false
                    && task.isRoutine == false
                    && task.scheduledDate != nil
            }
        )
        descriptor.fetchLimit = 256
        let tasks = (try? context.fetch(descriptor)) ?? []

        let cal = Calendar.current
        let today = Date()
        let center = UNUserNotificationCenter.current()

        for slot in RoutineSlot.allCases {
            // Tasks occurring today whose time-of-day falls in this window.
            let inWindow = tasks
                .compactMap { task -> (task: Task, at: Date)? in
                    guard let occ = task.occurrenceDate(on: today, calendar: cal) else { return nil }
                    let hour = cal.component(.hour, from: occ)
                    return RoutineSlot.from(hour: hour) == slot ? (task, occ) : nil
                }
                .sorted { $0.at < $1.at }
            guard !inWindow.isEmpty else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(slotTitle(slot)) tasks"
            content.body = windowBody(for: inWindow.map(\.task))
            content.sound = .default
            content.userInfo = [
                "type": "window_reminder",
                "slot": slot.rawValue,
            ]
            content.threadIdentifier = "window"

            var comps = DateComponents()
            comps.hour = windowReminderHour(for: slot)
            comps.minute = 0
            let req = request(id: "\(windowPrefix)\(slot.rawValue)", comps: comps, content: content, repeats: true)
            center.add(req) { error in
                guard let error else { return }
                _Concurrency.Task { @MainActor in
                    AnalyticsErrorReporter.report(error, context: "notifications.window.add")
                }
            }
        }
    }

    static func cancelAllWindowReminders() {
        cancelByPrefix(windowPrefix)
    }

    // MARK: - Upcoming event reminders

    /// One-shot reminders for imported calendar events starting in the next
    /// 14 days, firing at the event's start time. Events get no recurrence
    /// handling — each instance is already a distinct row. Past events are
    /// excluded by the fetch predicate.
    static func refreshAllEventReminders(context: ModelContext) {
        cancelByPrefix(eventPrefix)

        guard let store = AppStore.activeInstanceForWidgetRefresh,
              store.notificationsEnabled,
              let userID = AuthManager.shared.currentUserID
        else { return }

        let now = Date()
        let horizon = Calendar.current.date(byAdding: .day, value: 14, to: now) ?? now
        var descriptor = FetchDescriptor<ImportedEvent>(
            predicate: #Predicate { e in
                e.userID == userID && e.startDate > now && e.startDate < horizon
            },
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        descriptor.fetchLimit = 256
        let events = (try? context.fetch(descriptor)) ?? []

        var pending: [UNNotificationRequest] = []
        var droppedEventCount = 0
        for event in events {
            if pending.count + 1 > eventReminderCap {
                droppedEventCount += 1
                continue
            }
            pending.append(buildRequest(for: event))
        }

        if droppedEventCount > 0 {
            Analytics.track(.eventRemindersCapped(droppedCount: droppedEventCount))
        }

        let center = UNUserNotificationCenter.current()
        for request in pending {
            center.add(request) { error in
                guard let error else { return }
                _Concurrency.Task { @MainActor in
                    AnalyticsErrorReporter.report(error, context: "notifications.event.add")
                }
            }
        }
    }

    static func cancelAllEventReminders() {
        cancelByPrefix(eventPrefix)
    }

    /// Build 0, 1, or 5 requests for a Task.
    /// `.none` recurrence in the past: skipped (would never fire).
    /// `.none` recurrence in the future: one one-shot trigger.
    /// Recurring: same component mapping as routines.
    private static func buildRequests(for task: Task) -> [UNNotificationRequest] {
        guard let scheduledDate = task.scheduledDate,
              !task.isCompleted,
              !task.isRoutine else { return [] }

        let content = UNMutableNotificationContent()
        content.title = task.title
        content.sound = .default
        content.userInfo = [
            "type": "task_reminder",
            "task_id": task.id.uuidString,
            "deep_link": "flowstate://task/\(task.id.uuidString)",
        ]
        content.threadIdentifier = "task"

        let baseID = "\(taskPrefix)\(task.id.uuidString)"
        let cal = Calendar.current
        let hour = cal.component(.hour, from: scheduledDate)
        let minute = cal.component(.minute, from: scheduledDate)

        switch task.recurrence {
        case .none:
            // One-shot. Past dates would never fire — skip them so they
            // don't eat slot budget.
            guard scheduledDate > Date() else { return [] }
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: scheduledDate)
            return [request(id: baseID, comps: comps, content: content, repeats: false)]

        case .daily:
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            return [request(id: baseID, comps: comps, content: content, repeats: true)]

        case .weekdays:
            return (2...6).map { weekday in
                var comps = DateComponents()
                comps.hour = hour
                comps.minute = minute
                comps.weekday = weekday
                return request(id: "\(baseID).wd.\(weekday)", comps: comps, content: content, repeats: true)
            }

        case .weekly:
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            comps.weekday = cal.component(.weekday, from: scheduledDate)
            return [request(id: baseID, comps: comps, content: content, repeats: true)]

        case .monthly:
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            comps.day = cal.component(.day, from: scheduledDate)
            return [request(id: baseID, comps: comps, content: content, repeats: true)]
        }
    }

    // MARK: - Builders

    /// Build 0, 1, or 5 `UNNotificationRequest`s for a single group.
    /// Returns empty for `.none` recurrence (group materializes but never reminds).
    private static func buildRequests(
        for group: RoutineGroup,
        context: ModelContext
    ) -> [UNNotificationRequest] {
        guard group.recurrence != .none else { return [] }

        let hour = group.reminderHour ?? defaultHour(for: group.slot)
        let minute = group.reminderMinute ?? 0

        let content = UNMutableNotificationContent()
        let emoji = (group.emoji?.isEmpty == false) ? "\(group.emoji!) " : ""
        content.title = "\(emoji)\(group.title)"
        content.body = bodyText(for: group, context: context)
        content.sound = .default
        content.userInfo = [
            "type": "routine_reminder",
            "group_id": group.id.uuidString,
            "deep_link": "flowstate://routine/\(group.id.uuidString)",
        ]
        content.threadIdentifier = "routine"

        let baseID = "\(routinePrefix)\(group.id.uuidString)"

        switch group.recurrence {
        case .daily:
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            return [request(id: baseID, comps: comps, content: content, repeats: true)]

        case .weekdays:
            // Mon (Gregorian weekday=2) … Fri (=6). One trigger each — the
            // calendar trigger only matches a single weekday at a time.
            return (2...6).map { weekday in
                var comps = DateComponents()
                comps.hour = hour
                comps.minute = minute
                comps.weekday = weekday
                return request(id: "\(baseID).wd.\(weekday)", comps: comps, content: content, repeats: true)
            }

        case .weekly:
            // Anchor weekly cadence to the day-of-week the group was created on.
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            comps.weekday = Calendar.current.component(.weekday, from: group.createdAt)
            return [request(id: baseID, comps: comps, content: content, repeats: true)]

        case .monthly:
            // Anchor monthly cadence to the day-of-month the group was created on.
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            comps.day = Calendar.current.component(.day, from: group.createdAt)
            return [request(id: baseID, comps: comps, content: content, repeats: true)]

        case .none:
            return []
        }
    }

    private static func request(
        id: String,
        comps: DateComponents,
        content: UNMutableNotificationContent,
        repeats: Bool
    ) -> UNNotificationRequest {
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: repeats)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    /// One-shot request for an imported calendar event, firing at its start.
    private static func buildRequest(for event: ImportedEvent) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = eventBody(for: event)
        content.sound = .default
        content.userInfo = [
            "type": "event_reminder",
            "event_id": event.id.uuidString,
        ]
        content.threadIdentifier = "event"

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: event.startDate
        )
        return request(id: "\(eventPrefix)\(event.id.uuidString)", comps: comps, content: content, repeats: false)
    }

    private static let eventTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    private static func eventBody(for event: ImportedEvent) -> String {
        let time = eventTimeFormatter.string(from: event.startDate)
        if let cal = event.calendarTitle, !cal.isEmpty {
            return "Starts at \(time) · \(cal)"
        }
        return "Starts at \(time)"
    }

    /// "💻 Deep work · 🥗 Lunch · 📞 Call dentist · +2 more" — first 3 task
    /// titles in the window, then an overflow count. Quiet, no urgency copy.
    private static func windowBody(for tasks: [Task]) -> String {
        guard !tasks.isEmpty else { return "You've got tasks lined up." }
        let visible = tasks.prefix(3).map(\.title)
        let extra = tasks.count - visible.count
        var body = visible.joined(separator: " · ")
        if extra > 0 { body += " · +\(extra) more" }
        return body
    }

    /// Hour the window reminder fires — the front of each window so the nudge
    /// lands as the user enters that part of the day.
    private static func windowReminderHour(for slot: RoutineSlot) -> Int {
        switch slot {
        case .morning:   return 9
        case .afternoon: return 13
        case .evening:   return 18
        }
    }

    private static func slotTitle(_ slot: RoutineSlot) -> String {
        switch slot {
        case .morning:   return "Morning"
        case .afternoon: return "Afternoon"
        case .evening:   return "Evening"
        }
    }

    /// "💧 Water · 🧘 Stretch · 📖 Read" — first 3 tags, then "+ N more".
    /// Quiet brand voice; no exclamation, no urgency copy.
    private static func bodyText(for group: RoutineGroup, context: ModelContext) -> String {
        let groupID = group.id
        let descriptor = FetchDescriptor<RoutineTag>(
            predicate: #Predicate { $0.groupID == groupID },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let tags = (try? context.fetch(descriptor)) ?? []
        guard !tags.isEmpty else { return "Time for your routine." }
        let visible = tags.prefix(3).map { "\($0.emoji) \($0.label)" }
        let extra = tags.count - visible.count
        var body = visible.joined(separator: " · ")
        if extra > 0 { body += " · +\(extra) more" }
        return body
    }

    /// Mirrors `RoutineScheduler.defaultHour` so legacy groups (created before
    /// `reminderHour` existed) still get a sensible fire time.
    private static func defaultHour(for slot: RoutineSlot) -> Int {
        switch slot {
        case .morning:   return 8
        case .afternoon: return 13
        case .evening:   return 20
        }
    }
}
