import SwiftUI

struct CircularTimer: View {
    let mode: TimerMode
    let secondsRemaining: Int
    let secondsElapsed: Int
    let totalSeconds: Int
    let arcColor: Color

    @Environment(\.palette) private var palette
    @State private var breath: Double = 1.0

    private var progress: Double {
        switch mode {
        case .countdown:
            guard totalSeconds > 0 else { return 0 }
            return min(max(Double(secondsRemaining) / Double(totalSeconds), 0), 1)
        case .countup:
            return 1.0
        }
    }

    private var numeralsText: String {
        switch mode {
        case .countdown: return Self.format(secondsRemaining)
        case .countup:   return Self.format(secondsElapsed)
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(palette.surfaceAlt, lineWidth: Geometry.timerRingStroke)
                .frame(width: Geometry.timerRingSize, height: Geometry.timerRingSize)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    arcColor,
                    style: StrokeStyle(
                        lineWidth: Geometry.timerRingStroke,
                        lineCap: .round
                    )
                )
                .frame(width: Geometry.timerRingSize, height: Geometry.timerRingSize)
                .rotationEffect(.degrees(-90))
                .opacity(mode == .countup ? breath : 1.0)
                .animation(.linear(duration: 0.4), value: progress)

            Text(numeralsText)
                .font(AppFont.timerNumerals)
                .tracking(AppFont.timerTracking)
                .foregroundStyle(palette.textPrimary)
                .monospacedDigit()
        }
        .onAppear { applyBreathing() }
        .onChange(of: mode) { _, _ in applyBreathing() }
    }

    private func applyBreathing() {
        if mode == .countup {
            breath = 1.0
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                breath = 0.55
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                breath = 1.0
            }
        }
    }

    static func format(_ seconds: Int) -> String {
        let s = max(seconds, 0)
        if s >= 3600 {
            let h = s / 3600
            let m = (s % 3600) / 60
            let sec = s % 60
            return String(format: "%d:%02d:%02d", h, m, sec)
        } else {
            let m = s / 60
            let sec = s % 60
            return String(format: "%02d:%02d", m, sec)
        }
    }
}
