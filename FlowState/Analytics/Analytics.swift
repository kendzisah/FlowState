import Foundation

/// Public façade for analytics. Call sites use only this enum-y namespace —
/// they don't import AppsFlyerLib or PostHog directly. That keeps the SDK
/// surface confined to `AppsFlyerProvider` and `PostHogProvider`, makes
/// callsites easy to scan, and means we can swap providers without touching
/// the rest of the codebase.
///
/// Every method delegates to `AnalyticsManager.shared`. Calls made before
/// `AnalyticsManager.shared.configure()` are no-ops (intentional — see
/// `AnalyticsManager` doc).
enum Analytics {

    /// Track an event. See `AnalyticsEvent` for the catalogue.
    static func track(_ event: AnalyticsEvent) {
        AnalyticsManager.shared.track(event)
    }

    /// Associate the current device with a user. Call from
    /// `AuthManager.persist(...)` after sign-in/sign-up.
    static func identify(userID: String, traits: [String: Any]? = nil) {
        AnalyticsManager.shared.identify(userID: userID, traits: traits)
    }

    /// Disconnect from the current user. Call from `AuthManager.clear()`
    /// after sign-out / account-delete. PostHog clears the distinct_id;
    /// AppsFlyer clears the customer user ID.
    static func reset() {
        AnalyticsManager.shared.reset()
    }

    /// Manual `$screen` event for SwiftUI route transitions where UIKit
    /// autocapture doesn't fire reliably. See posthog-spec.md §6.
    static func screen(_ name: String, properties: [String: Any]? = nil) {
        AnalyticsManager.shared.screen(name, properties: properties)
    }

    /// Set a user property (e.g. `theme_mode`, `entitled`). Overwrites.
    /// Use `setUserPropertyOnce` for first-set-wins values like signup date.
    static func setUserProperty(key: String, value: Any) {
        AnalyticsManager.shared.setUserProperty(key: key, value: value)
    }
}
