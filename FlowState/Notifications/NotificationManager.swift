import Foundation
import SwiftData
import UserNotifications

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

    private static let timerCompleteIdentifier = "com.flocktechnologies.FlowState.timerComplete"
    private static let routinePrefix = "routine."
    private static let taskPrefix = "task."

    /// iOS limits 64 pending notifications app-wide. We split the budget:
    ///   • 1 timer-complete
    ///   • up to 32 routine reminders
    ///   • up to 28 scheduled-task reminders
    ///   • 3 slot buffer
    private static let routineReminderCap = 32
    private static let taskReminderCap = 28

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
                if let error {
                    AnalyticsErrorReporter.report(error, context: "notifications.routine.add")
                }
            }
        }
    }

    static func cancelAllRoutineReminders() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(routinePrefix) }
            guard !ids.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: ids)
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
                if let error {
                    AnalyticsErrorReporter.report(error, context: "notifications.task.add")
                }
            }
        }
    }

    static func cancelAllTaskReminders() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(taskPrefix) }
            guard !ids.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
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
