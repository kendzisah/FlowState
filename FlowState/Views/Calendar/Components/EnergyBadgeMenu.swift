import SwiftUI

/// Tap target showing the current energy. Tap → menu of options + Auto-classify.
struct EnergyBadgeMenu: View {
    let current: EnergyLevel?
    let isUserOverride: Bool
    var isClassifying: Bool = false
    let onPick: (EnergyLevel) -> Void
    let onAutoClassify: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Menu {
            ForEach(EnergyLevel.taskAssignable, id: \.self) { level in
                Button {
                    onPick(level)
                } label: {
                    Label {
                        Text(level.shortLabel)
                    } icon: {
                        Image(systemName: level.iconName)
                    }
                }
            }
            Divider()
            Button {
                onAutoClassify()
            } label: {
                Label("Auto-classify", systemImage: "sparkles")
            }
        } label: {
            EnergyBadge(level: current, isUserOverride: isUserOverride, isClassifying: isClassifying)
        }
        .disabled(isClassifying)
        .accessibilityLabel("Energy: \(current?.shortLabel ?? "Unset"). \(isClassifying ? "Classifying." : "Tap to change.")")
    }
}

struct EnergyBadge: View {
    let level: EnergyLevel?
    var isUserOverride: Bool = false
    var isClassifying: Bool = false

    @Environment(\.palette) private var palette
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isClassifying ? "sparkles" : (level?.iconName ?? "circle.dashed"))
                .font(.system(size: 10, weight: .bold))
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isClassifying)
            Text(isClassifying ? "CLASSIFYING…" : (level?.shortLabel.uppercased() ?? "TAG"))
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
        }
        .foregroundStyle(level == nil ? palette.textDimmed : palette.onEnergy)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(level?.color(in: palette) ?? palette.surfaceAlt)
        )
        .overlay(
            Capsule()
                .stroke(level == nil ? palette.border : Color.clear, lineWidth: 1)
        )
        .opacity(isClassifying ? (pulse ? 0.55 : 1) : 1)
        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)
        .onAppear { if isClassifying { pulse = true } }
        .onChange(of: isClassifying) { _, now in pulse = now }
    }
}
