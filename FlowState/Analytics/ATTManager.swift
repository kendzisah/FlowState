import Foundation
import AppTrackingTransparency
import AdSupport

/// Owns the App Tracking Transparency prompt and the bookkeeping around it.
///
/// Per the plan: the ATT prompt fires once, after onboarding completes,
/// before the user reaches the paywall (or home, if entitled). This timing
/// gives the user context for why we're asking — and is the only chance
/// AppsFlyer has to capture IDFA for attribution.
///
/// Idempotent — multiple `requestIfNeeded()` calls only show the prompt
/// the first time the user has `.notDetermined` status.
@MainActor
enum ATTManager {

    private static var requestedThisLaunch = false

    /// Returns true if iOS has already recorded a final ATT decision
    /// (granted / denied / restricted). False means we either haven't
    /// asked yet or iOS is reporting `.notDetermined`.
    static var isResolved: Bool {
        ATTrackingManager.trackingAuthorizationStatus != .notDetermined
    }

    /// Show the ATT system prompt. Safe to call multiple times — iOS will
    /// only display the alert once per install. We guard against repeated
    /// in-session calls to avoid stacking analytics events.
    static func requestIfNeeded() async {
        guard !requestedThisLaunch else { return }
        requestedThisLaunch = true

        // If iOS already has a decision (e.g. user denied previously),
        // record the cached status as an event for visibility and bail.
        let initialStatus = ATTrackingManager.trackingAuthorizationStatus
        guard initialStatus == .notDetermined else {
            Analytics.track(.attPermissionResult(status: statusString(initialStatus)))
            return
        }

        Analytics.track(.attPermissionRequested)
        let status = await ATTrackingManager.requestTrackingAuthorization()
        Analytics.track(.attPermissionResult(status: statusString(status)))

        // If granted, push the freshly-collectable IDFA into RC so it gets
        // forwarded to AppsFlyer with the next S2S purchase event.
        if status == .authorized {
            await SubscriptionManager.shared.refreshAppsFlyerAttribution()
        }
    }

    private static func statusString(_ status: ATTrackingManager.AuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted:    return "restricted"
        case .denied:        return "denied"
        case .authorized:    return "authorized"
        @unknown default:    return "unknown"
        }
    }
}
