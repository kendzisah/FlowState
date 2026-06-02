import Foundation
import PostHog

/// PostHog adapter. See analytics/posthog-spec.md.
///
/// What this provider does:
///   • Initializes the SDK with autocapture (screens + interactions +
///     lifecycle) enabled and session replay disabled.
///   • Enables the SDK's built-in crash autocapture (`errorTrackingConfig.
///     autoCapture = true`) so Mach exceptions, POSIX signals, and uncaught
///     NSExceptions get reported automatically.
///   • Routes our typed events through `capture(_:properties:)`.
///   • Wires identify → reset around AuthManager's persist/clear flow.
///
/// Notes on SwiftUI autocapture: PostHog's `captureElementInteractions`
/// flag relies on UIKit method swizzling and doesn't reliably fire for
/// SwiftUI Buttons. All material taps must be tracked manually via
/// `Analytics.track(...)`. See posthog-spec.md §6.
final class PostHogProvider: AnalyticsProvider {
    static let shared = PostHogProvider()
    let name = "PostHog"

    private var initialized = false
    private init() {}

    func configure() {
        guard !initialized else { return }
        let apiKey = (Bundle.main.object(forInfoDictionaryKey: "PostHogAPIKey") as? String) ?? ""
        let host = (Bundle.main.object(forInfoDictionaryKey: "PostHogHost") as? String) ?? "https://us.i.posthog.com"

        guard !apiKey.isEmpty, !apiKey.contains("$("), apiKey.hasPrefix("phc_") else {
            // Misconfigured (e.g. xcconfig substitution didn't run) — skip
            // init rather than crashing. PostHog calls become no-ops.
            return
        }

        let config = PostHogConfig(projectToken: apiKey, host: host)
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = true
        config.captureElementInteractions = true
        config.sessionReplay = false

        // Anonymous events stay attached to the device's anonymous ID; we
        // only create a profile once identify() runs. Cheaper + privacy-safer.
        config.personProfiles = .identifiedOnly

        // Mobile batching — flush every 30s or every 20 events.
        config.flushAt = 20
        config.flushIntervalSeconds = 30
        config.maxQueueSize = 1000

        // Crash + signal autocapture. Swift errors caught in do/catch
        // blocks still go through AnalyticsErrorReporter manually.
        config.errorTrackingConfig.autoCapture = true

        #if DEBUG
        config.debug = true
        #endif

        PostHogSDK.shared.setup(config)
        initialized = true
    }

    // MARK: AnalyticsProvider

    func track(_ event: AnalyticsEvent) {
        guard initialized else { return }
        PostHogSDK.shared.capture(event.name, properties: event.properties)
    }

    func identify(userID: String, traits: [String: Any]?) {
        guard initialized else { return }
        PostHogSDK.shared.identify(userID, userProperties: traits ?? [:])
    }

    func reset() {
        guard initialized else { return }
        PostHogSDK.shared.reset()
    }

    func screen(_ name: String, properties: [String: Any]?) {
        guard initialized else { return }
        PostHogSDK.shared.screen(name, properties: properties)
    }

    func setUserProperty(key: String, value: Any) {
        guard initialized else { return }
        PostHogSDK.shared.capture("$set", properties: ["$set": [key: value]])
    }

    /// Force-flush queued events. Used before fatal error to maximize
    /// the chance the crash event reaches the server.
    func flushSync() {
        guard initialized else { return }
        PostHogSDK.shared.flush()
    }
}
