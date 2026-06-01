import SwiftUI

struct CompletionDialog: View {
    let state: CompletionDialogState
    var onDismiss: () -> Void

    @Environment(\.palette) private var palette

    @State private var cardScale: CGFloat = 0.8
    @State private var sparkleAngle: Double = -8
    @State private var sparkleScale: CGFloat = 0.7

    var body: some View {
        ZStack {
            palette.sheetBackdrop
                .ignoresSafeArea()
                .onTapGesture { dismiss(method: "tap_backdrop") }

            VStack(spacing: 22) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(palette.parkedAccent)
                    .scaleEffect(sparkleScale)
                    .rotationEffect(.degrees(sparkleAngle))

                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                    Text(AppStrings.completionPillLabel)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.6)
                }
                .foregroundStyle(palette.parkedText)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule().stroke(palette.parkedText.opacity(0.7), lineWidth: 1.2)
                )

                Text(state.taskTitle)
                    .font(.system(size: 18, weight: .medium).italic())
                    .foregroundStyle(palette.parkedText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                Text("\u{201C}\(state.affirmation)\u{201D}")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(palette.parkedText.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Button(action: { dismiss() }) {
                    Text(AppStrings.completionDismiss)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.parkedBg)
                        .frame(maxWidth: .infinity, minHeight: Geometry.minTapTarget)
                        .background(
                            RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                                .fill(palette.parkedText)
                        )
                }
                .buttonStyle(.pressable)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: Geometry.sheetRadius, style: .continuous)
                    .fill(palette.parkedBg)
                    .overlay(
                        ZStack {
                            RadialGradient(
                                colors: [palette.captionPulse.opacity(0.18), .clear],
                                center: .topLeading, startRadius: 0, endRadius: 220
                            )
                            RadialGradient(
                                colors: [palette.energyScattered.opacity(0.12), .clear],
                                center: .bottomTrailing, startRadius: 0, endRadius: 220
                            )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Geometry.sheetRadius, style: .continuous))
                    )
                    .shadow(color: .black.opacity(0.35), radius: 22, x: 0, y: 14)
            )
            .padding(.horizontal, 24)
            .scaleEffect(cardScale)
        }
        .onAppear {
            animateIn()
            Analytics.track(.completionDialogShown(taskID: state.id.uuidString))
        }
        .accessibilityAddTraits(.isModal)
    }

    private func animateIn() {
        cardScale = 0.8
        sparkleAngle = -8
        sparkleScale = 0.7

        withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) {
            cardScale = 1.04
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.85).delay(0.18)) {
            cardScale = 1.0
        }
        withAnimation(.easeOut(duration: 1.4)) {
            sparkleAngle = 12
            sparkleScale = 1.05
        }
    }

    private func dismiss(method: String = "tap_button") {
        Analytics.track(.completionDialogDismissed(taskID: state.id.uuidString, method: method))
        withAnimation(.easeIn(duration: 0.18)) {
            cardScale = 0.95
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            onDismiss()
        }
    }
}
