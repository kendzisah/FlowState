import SwiftUI

struct OnbPrimaryButton: View {
    let title: String
    var enabled: Bool = true
    var inFlight: Bool = false
    var systemImage: String? = nil
    var trailingSystemImage: String? = nil
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button {
            guard enabled, !inFlight else { return }
            action()
        } label: {
            ZStack {
                HStack(spacing: 8) {
                    if let img = systemImage {
                        Image(systemName: img)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                    if let trailing = trailingSystemImage {
                        Image(systemName: trailing)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundStyle(palette.onEnergy)
                .opacity(inFlight ? 0 : 1)

                if inFlight {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(palette.onEnergy)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Geometry.minTapTarget)
            .background(
                RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                    .fill(enabled ? palette.energySteady : palette.surfaceAlt)
            )
            .opacity(enabled ? 1 : 0.6)
        }
        .buttonStyle(.pressable)
        .disabled(!enabled || inFlight)
    }
}

struct OnbSecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let img = systemImage {
                    Image(systemName: img)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(palette.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Geometry.minTapTarget)
            .background(
                RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                    .stroke(palette.border, lineWidth: 1.5)
            )
        }
        .buttonStyle(.pressable)
    }
}
