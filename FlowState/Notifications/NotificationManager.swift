import Foundation
import UserNotifications

@MainActor
enum NotificationManager {
    private static let identifier = "com.flocktechnologies.FlowState.timerComplete"
    private static var requestedAuth = false

    static func requestAuthorizationIfNeeded() async {
        guard !requestedAuth else { return }
        requestedAuth = true
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    static func scheduleCompletion(after seconds: Int) {
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = AppStrings.notificationCompletionTitle
        content.body  = AppStrings.notificationCompletionBody
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(request)
    }

    static func cancelCompletion() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
