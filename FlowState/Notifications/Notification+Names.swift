import Foundation

extension Notification.Name {
    /// Bridge from `NotificationDelegate` (which runs in response to a tap on
    /// a `UNNotification`) into the SwiftUI scene where `DeepLinkRouter` lives.
    /// Payload: `object` is the deep-link `URL` to route. Observed in
    /// `RootView` and forwarded to the same router that handles `.onOpenURL`.
    static let flowStateDeepLink = Notification.Name("FlowStateDeepLink")
}
