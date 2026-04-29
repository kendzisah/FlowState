import SwiftUI

struct EnergySwitcherSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(AppStrings.switcherTitle)
                    .font(AppFont.title)
                    .tracking(AppFont.titleTracking)
                    .foregroundStyle(palette.textPrimary)
                Text(AppStrings.switcherSubtitle)
                    .font(AppFont.body)
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(.top, 8)

            VStack(spacing: 10) {
                ForEach([EnergyLevel.foggy, .scattered, .steady, .locked], id: \.self) { level in
                    EnergyCard(
                        level: level,
                        isCurrent: store.energyLevel == level
                    ) {
                        store.setEnergy(level)
                        dismiss()
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .presentationDetents([.fraction(0.6), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Geometry.sheetRadius)
        .presentationBackground(palette.surface)
    }
}
