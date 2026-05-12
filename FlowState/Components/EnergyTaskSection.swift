import SwiftUI

/// Collapsible section grouping today's tasks by `EnergyLevel`. Mirrors the
/// shape of `RoutineSlotSection` so the home tab reads as one coherent
/// pattern (group → progress → expandable rows).
///
/// The section that matches the user's current energy is `defaultExpanded`
/// and gets a subtle tint accent on the header. Other sections render
/// collapsed by default. Tap to expand/collapse — state lives per-session.
struct EnergyTaskSection<Content: View>: View {
    let level: EnergyLevel
    let count: Int
    let isMatching: Bool
    let defaultExpanded: Bool
    @ViewBuilder let content: () -> Content

    @Environment(\.palette) private var palette
    @State private var didSeed: Bool = false
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if isExpanded {
                VStack(spacing: 8) {
                    content()
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                .fill(isMatching
                      ? level.color(in: palette).opacity(0.10)
                      : palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                .stroke(isMatching ? level.color(in: palette).opacity(0.5) : palette.border, lineWidth: 1)
        )
        .onAppear {
            guard !didSeed else { return }
            isExpanded = defaultExpanded
            didSeed = true
        }
    }

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: level.iconName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(level.color(in: palette))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(level.shortLabel.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(palette.textPrimary)
                        Text("(\(count))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.textSecondary)
                        if isMatching {
                            Text("MATCHES YOU")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.8)
                                .foregroundStyle(palette.onEnergy)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(level.color(in: palette)))
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(palette.textDimmed)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(level.shortLabel), \(count) tasks, \(isExpanded ? "collapse" : "expand")")
    }
}
