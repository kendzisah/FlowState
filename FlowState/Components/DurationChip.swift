import SwiftUI

struct DurationChip: View {
    let mode: TimerMode
    let totalSeconds: Int
    var onTap: () -> Void

    @Environment(\.palette) private var palette

    private var label: String {
        switch mode {
        case .countdown: return "\(totalSeconds / 60) min"
        case .countup:   return AppStrings.durationNoCap
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(palette.surface)
                    .overlay(Capsule().stroke(palette.border, lineWidth: 1))
            )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Duration: \(label). Tap to change.")
    }
}
