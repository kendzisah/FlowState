import SwiftUI

struct EnergyCard: View {
    let level: EnergyLevel
    var isCurrent: Bool = false
    var action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: level.iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.onEnergy)
                    .frame(width: 32)
                Text(level.label)
                    .font(AppFont.body)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(palette.onEnergy)
                Spacer(minLength: 8)
                if isCurrent {
                    Text(AppStrings.switcherCurrentBadge)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(palette.onEnergy)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().stroke(palette.onEnergy.opacity(0.7), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: Geometry.energyCardMinHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                    .fill(level.color(in: palette))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                    .stroke(isCurrent ? palette.textPrimary : .clear, lineWidth: 2)
            )
            .shadow(color: palette.cardShadow, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(level.label)
    }
}
