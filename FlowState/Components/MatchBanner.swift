import SwiftUI

struct MatchBanner: View {
    let count: Int
    let level: EnergyLevel
    @Environment(\.palette) private var palette

    var body: some View {
        Text(AppStrings.matchBanner(count: count, energyLabel: level.shortLabel.lowercased()))
            .font(AppFont.caption)
            .foregroundStyle(palette.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
