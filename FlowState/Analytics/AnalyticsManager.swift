import Foundation

/// Fans out analytics calls to every registered provider.
///
/// Designed so call sites don't depend on which providers exist. Adding
/// a third destination later means writing one new AnalyticsProvider
/// adapter and adding it to `providers` — no callsite changes.
///
/// Thread model: writes to `providers` happen only in `configure()` on
/// the main actor. Reads happen from any actor via `fanout` — each
/// provider's adapter is responsible for its own internal threading.
final class AnalyticsManager: @unchecked Sendable {
    static let shared = AnalyticsManager()

    private var providers: [AnalyticsProvider] = []
    private var configured = false

    private init() {}

    /// Call once at app launch (FlowStateApp.init).
    func configure() {
        guard !configured else { return }
        configured = true

        // Order matters: PostHog first so its lifecycle observers
        // register before AppsFlyer's NotificationCenter observer fires
        // the first didBecomeActive.
        let posthog = PostHogProvider.shared
        let appsflyer = AppsFlyerProvider.shared

        posthog.configure()
        appsflyer.configure()

        providers = [posthog, appsflyer]
    }

    // MARK: - Fanout

    func track(_ event: AnalyticsEvent) {
        for p in providers { p.track(event) }
    }

    func identify(userID: String, traits: [String: Any]?) {
        for p in providers { p.identify(userID: userID, traits: traits) }
    }

    func reset() {
        for p in providers { p.reset() }
    }

    func screen(_ name: String, properties: [String: Any]? = nil) {
        for p in providers { p.screen(name, properties: properties) }
    }

    func setUserProperty(key: String, value: Any) {
        for p in providers { p.setUserProperty(key: key, value: value) }
    }
}
