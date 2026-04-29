import SwiftUI

struct DriftingFogBlob: View {
    let size: CGFloat
    let color: Color
    let opacity: Double
    let phase: Double           // 0..1, randomizes start
    let durationSeconds: Double // 18-26

    @State private var animate = false

    var body: some View {
        Circle()
            .fill(color.opacity(opacity))
            .frame(width: size, height: size)
            .blur(radius: size * 0.45)
            .offset(
                x: animate ? size * 0.6 : -size * 0.6,
                y: animate ? -size * 0.25 : size * 0.25
            )
            .blendMode(.screen)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: durationSeconds)
                    .repeatForever(autoreverses: true)
                    .delay(phase * durationSeconds)
                ) {
                    animate = true
                }
            }
    }
}
