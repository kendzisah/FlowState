import SwiftUI

struct CheckInView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(AppStrings.checkInPrompt)
                .font(AppFont.title)
                .tracking(AppFont.titleTracking)
                .foregroundStyle(palette.textPrimary)
                .padding(.top, 32)

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                ForEach([EnergyLevel.foggy, .scattered, .steady, .locked], id: \.self) { level in
                    EnergyCard(level: level) {
                        store.setEnergy(level)
                    }
                }
            }

            Spacer(minLength: 32)
        }
        .padding(.horizontal, Geometry.horizontalPadding)
    }
}
