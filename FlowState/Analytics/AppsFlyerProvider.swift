import Foundation
import AppsFlyerLib
import UIKit

/// AppsFlyer adapter. See analytics/appsflyer-spec.md.
///
/// What this provider does NOT do:
///   • Send revenue events (`af_purchase` / `af_start_trial` / `af_subscribe`).
///     RevenueCat's AppsFlyer S2S integration owns those — sending from the
///     client too would double-count. See appsflyer-spec.md §3.
///
/// What it does:
///   • Initializes the SDK and wires `waitForATTUserAuthorization` with a
///     120s timeout so the ATT prompt (fired post-onboarding by ATTManager)
///     can resolve before AppsFlyer ships its first session.
///   • Starts the SDK on every `didBecomeActive` so AppsFlyer logs
///     `af_app_opened` per launch (matches AppsFlyer's recommended pattern
///     for SceneDelegate-less SwiftUI apps).
///   • Sets/clears `customerUserID` on identify/reset so install + post-install
///     events carry the Supabase user ID (matches RC's `app_user_id`).
///   • Bridges install attribution into PostHog via `appsflyer_conversion`
///     event so acquisition source is queryable alongside product analytics.
final class AppsFlyerProvider: NSObject, AnalyticsProvider {
    static let shared = AppsFlyerProvider()
    let name = "AppsFlyer"

    private var didBecomeActiveObserver: NSObjectProtocol?
    private var sdkReady = false

    private override init() { super.init() }

    func configure() {
        let lib = AppsFlyerLib.shared()

        let devKey = (Bundle.main.object(forInfoDictionaryKey: "AppsFlyerDevKey") as? String) ?? ""
        let appID = (Bundle.main.object(forInfoDictionaryKey: "AppleAppID") as? String) ?? ""

        guard !devKey.isEmpty, !devKey.contains("$("), !appID.isEmpty, !appID.contains("$(") else {
            // Misconfigured — skip init. Calls become no-ops.
            return
        }

        lib.appsFlyerDevKey = devKey
        lib.appleAppID = appID
        lib.delegate = self
        lib.deepLinkDelegate = self

        #if DEBUG
        lib.isDebug = true
        #endif

        // ATT prompt fires after onboarding (see ATTManager). Give the
        // SDK 120s to wait for that decision before sending the first
        // session — otherwise IDFA is lost on installs that ATT-grant.
        lib.waitForATTUserAuthorization(timeoutInterval: 120)

        // If we already have a signed-in user from a prior session, set
        // CUID before start() so the install/session event carries it.
        if let cuid = AuthManager.shared.currentUserID {
            lib.customerUserID = cuid
        }

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { _ in
            AppsFlyerLib.shared().start()
        }
    }

    // MARK: AnalyticsProvider

    func track(_ event: AnalyticsEvent) {
        guard let mapping = event.appsFlyerMapping else { return }
        AppsFlyerLib.shared().logEvent(name: mapping.name, values: mapping.values)
    }

    func identify(userID: String, traits: [String: Any]?) {
        AppsFlyerLib.shared().customerUserID = userID
        // Push the AppsFlyer ID + device identifiers into RevenueCat so
        // its S2S integration can route purchase events back to AppsFlyer
        // for this user. Safe to call multiple times — RC dedupes.
        _Concurrency.Task { @MainActor in
            await SubscriptionManager.shared.refreshAppsFlyerAttribution()
        }
    }

    func reset() {
        AppsFlyerLib.shared().customerUserID = nil
    }

    func screen(_ name: String, properties: [String: Any]?) {
        // AppsFlyer has no native $screen — handled by PostHog.
    }

    func setUserProperty(key: String, value: Any) {
        // AppsFlyer has no native user properties API — handled by PostHog.
    }
}

// MARK: - AppsFlyerLibDelegate

extension AppsFlyerProvider: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        sdkReady = true
        // Bridge raw attribution into PostHog so acquisition source becomes
        // a queryable dimension on every downstream product event.
        var props: [String: Any] = [:]
        for (k, v) in data {
            if let key = k as? String { props[key] = v }
        }
        Analytics.track(.appsFlyerConversion(properties: props))

        // Now that AppsFlyer has its identifier, push it into RevenueCat.
        _Concurrency.Task { @MainActor in
            await SubscriptionManager.shared.refreshAppsFlyerAttribution()
        }
    }

    func onConversionDataFail(_ error: Error) {
        AnalyticsErrorReporter.report(error, context: "appsflyer.conversion")
    }
}

// MARK: - DeepLinkDelegate

extension AppsFlyerProvider: DeepLinkDelegate {
    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard let link = result.deepLink else { return }
        let scheme = link.deeplinkValue ?? link.clickHTTPReferrer ?? "unknown"
        Analytics.track(.deepLinkOpened(scheme: scheme, source: "appsflyer"))
    }
}
