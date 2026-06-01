import Foundation
import RevenueCat

/// Wraps RevenueCat's `Purchases` SDK and bridges entitlement state into `AppStore`.
///
/// Lifecycle:
///   1. `configure()` once at app launch (FlowStateApp.init).
///   2. `bind(to:)` once after the root view appears, to mirror entitlement
///      updates from `Purchases.shared.customerInfoStream` into `store.entitled`.
///
/// Sign-in / sign-out path: AuthManager calls `logIn(userID:)` and `logOut()`
/// here so we can `await` the resulting `CustomerInfo` and apply it
/// synchronously. The customerInfoStream observer would eventually deliver the
/// same payload, but the stream is lazy — relying on it alone produces a
/// 1–2s flash where the route gate sees stale `entitled = false` after a
/// sign-in.
///
/// Entitlement of record: `proEntitlementID` ("FlowState Pro"). All Pro
/// gating reads from `store.entitled`; this manager is the only writer.
@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    /// Must match the entitlement identifier configured in the RevenueCat dashboard.
    static let proEntitlementID = "FlowState Pro"

    private(set) var customerInfo: CustomerInfo?
    private(set) var lastError: String?

    @ObservationIgnored
    private weak var boundStore: AppStore?

    @ObservationIgnored
    private var bindingTask: _Concurrency.Task<Void, Never>?

    private init() {}

    var isPro: Bool {
        customerInfo?.entitlements[Self.proEntitlementID]?.isActive == true
    }

    /// Reads the API key from Info.plist (`$(REVENUECAT_API_KEY)` xcconfig
    /// passthrough) and configures the SDK. Safe to call multiple times — the
    /// second call is a no-op inside RevenueCat.
    func configure() {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String,
              !key.isEmpty,
              key != "REPLACE_ME" else {
            lastError = "Missing REVENUECAT_API_KEY in Info.plist / Secrets.xcconfig"
            return
        }
        Purchases.logLevel = .info
        Purchases.configure(withAPIKey: key)
    }

    /// Subscribes to customer info updates and mirrors entitlement state into AppStore.
    /// Cancels any previous binding before starting a new one. Holds a weak
    /// reference to the store so `logIn` / `logOut` can update it eagerly without
    /// waiting for the stream to emit.
    func bind(to store: AppStore) {
        boundStore = store
        bindingTask?.cancel()
        bindingTask = _Concurrency.Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                guard !_Concurrency.Task.isCancelled else { return }
                self?.updateFromStream(info)
            }
        }
    }

    /// Eagerly links the current RC anonymous user (or previously-linked user)
    /// to the Supabase user ID. Applies the returned customer info immediately
    /// so callers can rely on `store.entitled` being correct on return.
    func logIn(userID: String) async {
        do {
            let result = try await Purchases.shared.logIn(userID)
            apply(result.customerInfo, source: "login")
        } catch {
            lastError = error.localizedDescription
            AnalyticsErrorReporter.report(error, context: "subscription.login")
        }
    }

    /// Disconnects from the current user. Returns when RC has emitted a fresh
    /// anonymous customer info and we've applied it locally.
    func logOut() async {
        do {
            let info = try await Purchases.shared.logOut()
            apply(info, source: "logout")
        } catch {
            lastError = error.localizedDescription
            AnalyticsErrorReporter.report(error, context: "subscription.logout")
        }
    }

    /// Pull the current cached/fresh CustomerInfo and apply it. Used on cold
    /// launch (called from `AuthManager.restore`) so the route gate has the
    /// correct entitlement before `isRestoring` flips to false.
    func refreshFromCache() async {
        if let info = try? await Purchases.shared.customerInfo() {
            apply(info, source: "cache")
        }
    }

    /// Apply CustomerInfo and emit `entitlement_changed` when it flips.
    /// `source` distinguishes the trigger ("login", "logout", "cache",
    /// "stream") so dashboards can attribute conversions accurately.
    private func apply(_ info: CustomerInfo, source: String = "stream") {
        let nowEntitled = info.entitlements[Self.proEntitlementID]?.isActive == true
        let wasEntitled = self.boundStore?.entitled ?? false
        self.customerInfo = info
        self.boundStore?.entitled = nowEntitled

        if nowEntitled != wasEntitled {
            Analytics.track(.entitlementChanged(entitled: nowEntitled, source: source))
            Analytics.setUserProperty(key: "entitled", value: nowEntitled)
        }
    }

    // Convenience wrapper used by the customerInfoStream subscriber so it
    // doesn't have to specify a source.
    fileprivate func applyFromStream(_ info: CustomerInfo) {
        apply(info, source: "stream")
    }
}

// Stream binding helper — kept in an extension so the source-aware `apply`
// above can stay private without surfacing it on the public API.
extension SubscriptionManager {
    func updateFromStream(_ info: CustomerInfo) {
        applyFromStream(info)
    }
}
