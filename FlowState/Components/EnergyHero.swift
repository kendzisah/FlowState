import SwiftUI

/// The home screen's hero header. Leads with the user's current energy state
/// (a large battery + "You're Steady right now") and demotes the date to a
/// subtitle — the opposite of a date-first planner header. The energy word is
/// tinted with the level's color, so the screen visibly shifts as energy
/// changes. Tapping anywhere opens the energy switcher.
struct EnergyHero: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var palette

    @State private var breath: Double = 1.0

    private var level: EnergyLevel { store.energyLevel ?? .steady }
    private var isFoggy: Bool { store.energyLevel == .foggy }

    var body: some View {
        Button {
            store.showEnergySwitcher = true
        } label: {
            HStack(spacing: 14) {
                BatteryIcon(
                    level: level,
                    bodyColor: palette.textSecondary,
                    fillColor: level.color(in: palette),
                    width: 54,
                    height: 26
                )
                .opacity(isFoggy ? breath : 1.0)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Group {
                            Text("You're ")
                                .foregroundStyle(palette.textPrimary)
                            + Text(level.shortLabel)
                                .foregroundStyle(level.color(in: palette))
                            + Text(" right now")
                                .foregroundStyle(palette.textPrimary)
                        }
                        .font(AppFont.title)
                        .tracking(AppFont.titleTracking)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(palette.textSecondary)
                    }

                    Text(dateLabel)
                        .font(AppFont.caption)
                        .foregroundStyle(palette.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Energy: \(level.shortLabel). Tap to change.")
        .onAppear { startBreathingIfFoggy() }
        .onChange(of: store.energyLevel) { _, _ in startBreathingIfFoggy() }
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    private func startBreathingIfFoggy() {
        if isFoggy {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                breath = 0.55
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                breath = 1.0
            }
        }
    }
}
