import SwiftUI

struct Step05SocialProof: View {
    @Environment(\.palette) private var palette

    /// Hardcoded for Phase A. Wire to remote config later if you want it dynamic.
    private let plannerCount: String = "12,000"

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            FoggyMascot(size: 110)

            VStack(spacing: 12) {
                Text("You're joining \(plannerCount) people planning their day with FlowState.")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(AppFont.titleTracking)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}
