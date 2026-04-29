import SwiftUI

struct BatteryPill: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        Button {
            store.showEnergySwitcher = true
        } label: {
            HStack(spacing: 10) {
                BatteryIcon(
                    level: currentLevel,
                    bodyColor: palette.textSecondary,
                    fillColor: currentLevel.color(in: palette),
                    width: 32,
                    height: 16
                )
                .opacity(isFoggy ? breath : 1.0)

                Text(currentLevel.shortLabel)
                    .font(AppFont.caption)
                    .foregroundStyle(palette.textPrimary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(palette.surface)
                    .overlay(Capsule().stroke(palette.border, lineWidth: 1))
            )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Energy: \(currentLevel.shortLabel). Tap to change.")
        .onAppear { startBreathingIfFoggy() }
        .onChange(of: store.energyLevel) { _, _ in startBreathingIfFoggy() }
    }

    private var currentLevel: EnergyLevel {
        store.energyLevel ?? .steady
    }

    private var isFoggy: Bool {
        store.energyLevel == .foggy
    }

    @State private var breath: Double = 1.0

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
