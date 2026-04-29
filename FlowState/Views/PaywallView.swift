import SwiftUI

struct PaywallView: View {
    var onStartTrial: () -> Void

    @Environment(\.palette) private var palette
    @State private var purchaseInFlight: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(palette.energySteady)
                    Text("FlowState Pro")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(palette.textSecondary)
                }

                Text("Try it free for 7 days.")
                    .font(.system(size: 30, weight: .bold))
                    .tracking(AppFont.titleTracking)
                    .foregroundStyle(palette.textPrimary)
            }

            VStack(alignment: .leading, spacing: 12) {
                bullet("All four energy states + Foggy rest mode")
                bullet("Mid-day energy switching with animated reorder")
                bullet("Count-up sessions for high focus")
                bullet("Live Activities + Dynamic Island")
                bullet("Local-only — your tasks never leave your device")
            }

            Spacer()

            VStack(spacing: 6) {
                Text("$2.99 / month after the trial. Cancel anytime.")
                    .font(AppFont.caption)
                    .foregroundStyle(palette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Button {
                if purchaseInFlight { return }
                purchaseInFlight = true
                _Concurrency.Task {
                    let ok = await ProductManager.shared.purchaseProTrial()
                    purchaseInFlight = false
                    if ok { onStartTrial() }
                }
            } label: {
                ZStack {
                    Text("Start free trial")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(palette.onEnergy)
                        .opacity(purchaseInFlight ? 0 : 1)
                    if purchaseInFlight {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(palette.onEnergy)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: Geometry.minTapTarget)
                .background(
                    RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                        .fill(palette.energySteady)
                )
            }
            .buttonStyle(.pressable)

            Button {
                if purchaseInFlight { return }
                _Concurrency.Task {
                    let ok = await ProductManager.shared.restorePurchases()
                    if ok { onStartTrial() }
                }
            } label: {
                Text("Restore purchases")
                    .font(AppFont.caption)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.bottom, 24)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.captionPulse)
                .padding(.top, 1)
            Text(text)
                .font(AppFont.body)
                .foregroundStyle(palette.textPrimary)
        }
    }
}
