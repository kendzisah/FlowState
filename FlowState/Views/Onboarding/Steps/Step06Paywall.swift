import SwiftUI
import RevenueCat

/// Onboarding step that presents the custom paywall. Same UI as the root-gate
/// `PaywallView`, but with a close affordance so users can defer Pro — the root
/// gate will catch them again unless they entered foggy-rest mode.
struct Step06Paywall: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void

    @Environment(AppStore.self) private var store

    var body: some View {
        PaywallView(
            onClose: onContinue,
            onCompleted: { info in
                draft.subscriptionStarted = true
                let entitled = info.entitlements[SubscriptionManager.proEntitlementID]?.isActive == true
                store.entitled = entitled
                Analytics.track(.onboardingPaywallCompleted(entitled: entitled))
                onContinue()
            }
        )
    }
}
