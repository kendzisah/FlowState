import SwiftUI

struct TipCard: View {
    let title: String
    let systemImage: String
    let onDismiss: () -> Void
    var onTap: (() -> Void)? = nil

    @Environment(\.palette) private var palette

    var body: some View {
        Button {
            onTap?()
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    Spacer(minLength: 0)
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(palette.surface)
                )

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Dismiss tip")
                .padding(4)
            }
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
    }
}
