import SwiftUI

struct Step02MarketingOptIn: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer().frame(height: 80)

            FoggyMascot(size: 64)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("Want product updates from FlowState?")
                .font(.system(size: 28, weight: .bold))
                .tracking(AppFont.titleTracking)
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.leading)

            VStack(spacing: 12) {
                OnbOptionCard(
                    title: "No thanks",
                    subtitle: "I don't want news, updates, or offers.",
                    isSelected: draft.marketingOptIn == false
                ) {
                    draft.marketingOptIn = false
                }
                OnbOptionCard(
                    title: "Yes, keep me posted",
                    subtitle: "Tell me about new features and offers.",
                    isSelected: draft.marketingOptIn == true
                ) {
                    draft.marketingOptIn = true
                }
            }

            Spacer()

            OnbPrimaryButton(title: "Continue", enabled: draft.marketingOptIn != nil) {
                if let v = draft.marketingOptIn {
                    Analytics.track(.onboardingMarketingOptIn(value: v))
                }
                onContinue()
            }

            Text("By continuing you agree to FlowState's Privacy Policy and Terms of Use.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(palette.textDimmed)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.bottom, 24)
    }
}
