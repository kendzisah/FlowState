import SwiftUI

/// A pill-shaped single-select option row used by Screens 2, 3, 4.
struct OnbOptionCard: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                ZStack {
                    Circle()
                        .stroke(isSelected ? palette.energySteady : palette.border, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(palette.energySteady)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: Geometry.minTapTarget, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                    .stroke(isSelected ? palette.energySteady : palette.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
