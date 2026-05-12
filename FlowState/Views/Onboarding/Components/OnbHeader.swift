import SwiftUI

struct OnbHeader: View {
    let progress: Double
    let showBack: Bool
    let showSkip: Bool
    let onBack: () -> Void
    let onSkip: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                if showBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(palette.textPrimary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Back")
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }

                Spacer()

                if showSkip {
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(palette.textSecondary)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Skip this step")
                }
            }
            .padding(.horizontal, 8)

            OnbProgressBar(progress: progress)
                .padding(.horizontal, Geometry.horizontalPadding)
        }
        .padding(.top, 4)
    }
}

struct OnbProgressBar: View {
    let progress: Double // 0..1
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.surfaceAlt)
                    .frame(height: 4)
                Capsule()
                    .fill(palette.energySteady)
                    .frame(width: geo.size.width * max(0, min(1, progress)), height: 4)
                    .animation(.easeInOut(duration: 0.28), value: progress)
            }
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityLabel("Step progress")
        .accessibilityValue("\(Int(progress * 100)) percent complete")
    }
}
