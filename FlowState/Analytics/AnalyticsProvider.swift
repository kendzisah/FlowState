import Foundation

/// One analytics destination (AppsFlyer, PostHog, etc.). All providers
/// receive the same call sequence — the dispatcher in `AnalyticsManager`
/// fans out to each provider's adapter.
///
/// Providers must be safe to instantiate before `configure()` is called;
/// `configure()` is what actually starts the underlying SDK. Calls made
/// before configure() are dropped (intentional — we don't buffer to avoid
/// memory pressure during the brief window before SDKs are ready).
protocol AnalyticsProvider: AnyObject {
    var name: String { get }

    func configure()
    func track(_ event: AnalyticsEvent)
    func identify(userID: String, traits: [String: Any]?)
    func reset()
    func screen(_ name: String, properties: [String: Any]?)
    func setUserProperty(key: String, value: Any)
}

extension AnalyticsProvider {
    var name: String { String(describing: type(of: self)) }
}
