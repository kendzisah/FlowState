import Foundation
import RevenueCat
import AppsFlyerLib

extension SubscriptionManager {
    /// Pushes the current AppsFlyer ID + collectable device identifiers
    /// (IDFA, IDFV) into RevenueCat. This is the prerequisite for
    /// RevenueCat's AppsFlyer S2S integration to route subscription
    /// events to the correct AppsFlyer user — without `$appsflyerId`
    /// set, RC falls back to its web API and some events are dropped.
    ///
    /// Call after:
    ///   • AppsFlyer SDK has reported install attribution (so `getAppsFlyerUID()`
    ///     is stable),
    ///   • the user signs in (`identify`),
    ///   • the ATT prompt resolves with `.authorized` (so a real IDFA exists).
    func refreshAppsFlyerAttribution() async {
        let afid = AppsFlyerLib.shared().getAppsFlyerUID()
        Purchases.shared.attribution.setAppsflyerID(afid)
        Purchases.shared.attribution.collectDeviceIdentifiers()
    }
}
