import SwiftUI

/// Foggy — FlowState's calming cloud mascot. Reuses the energyFoggy palette token
/// and a slow drift animation. Used on transition/loader screens.
struct FoggyMascot: View {
    var size: CGFloat = 96
    var animated: Bool = true

    @Environment(\.palette) private var palette
    @State private var floating = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                DriftingFogBlob(
                    size: size * 1.6,
                    color: palette.energyFoggy,
                    opacity: 0.32,
                    phase: Double(i) / 3.0,
                    durationSeconds: 18 + Double(i) * 3
                )
            }
            Image(systemName: "cloud.fill")
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(palette.energyFoggy)
                .shadow(color: palette.cardShadow, radius: 8, y: 4)
                .offset(y: animated && floating ? -6 : 0)
                .onAppear {
                    guard animated else { return }
                    withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                        floating = true
                    }
                }
        }
        .frame(width: size * 1.8, height: size * 1.8)
    }
}
