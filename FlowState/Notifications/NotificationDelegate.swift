import Foundation
import UserNotifications

/// Single delegate for every `UNUserNotificationCenter` event. Wired in
/// `FlowStateApp.init` so it's live the moment the process starts — taps
/// arriving before the SwiftUI scene exists still get routed.
///
/// Implementation deliberately tiny: we extract a `deep_link` URL from the
/// notification's `userInfo` (set at schedule time by `NotificationManager`)
/// and bridge it into the SwiftUI world via `NotificationCenter.default.post`.
/// `RootView` listens for `.flowStateDeepLink` and feeds the URL through
/// `DeepLinkRouter`, the same router that handles `.onOpenURL`. Keeping all
/// routing in one place means new notification types only need to populate
/// `userInfo["deep_link"]` — no new tap-handling code per notification.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()

    private override init() { super.init() }

    // MARK: - Foreground presentation

    /// Show banners + play sound even when the app is in the foreground.
    /// Without this iOS silently drops notifications while the app is open,
    /// which is wrong for routine reminders the user picked deliberately.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Tap

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        let userInfo = response.notification.request.content.userInfo
        guard let raw = userInfo["deep_link"] as? String,
              let url = URL(string: raw) else { return }
        NotificationCenter.default.post(name: .flowStateDeepLink, object: url)
    }
}
