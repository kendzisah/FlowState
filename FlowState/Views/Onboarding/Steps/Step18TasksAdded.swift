import SwiftUI

/// Final beat of onboarding. Runs *after* Step19's "I'm ready". Renders the
/// user's selected routine emojis as bubbles drifting upward, with a single
/// affirmation line in the center. Auto-progresses out via the coordinator's
/// auto-advance timer (2.5s) into `finishOnboarding`. The X in the top-right
/// short-circuits the wait.
struct Step18TasksAdded: View {
    @Bindable var draft: OnboardingDraft
    let onComplete: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            palette.surface
                .ignoresSafeArea()
                .opacity(0.0) // transparent so app background shows through

            FloatingEmojiBubbles(emojis: bubbleEmojis)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button(action: onComplete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(palette.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(palette.surface))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Done")
                }
                .padding(.horizontal, Geometry.horizontalPadding)
                .padding(.top, 12)

                Spacer()

                Text("You've got this!")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(AppFont.titleTracking)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
    }

    /// Bubbles are sourced from the user's own selections so the screen
    /// reflects their plan, not a generic confetti. Falls back to a default
    /// set when the user skipped all routine/task picks.
    private var bubbleEmojis: [String] {
        let fromRoutines = draft.allSelectedRoutines.map(\.emoji)
        let fromTasks = draft.selectedTasks.map { taskEmoji(for: $0) }
        let combined = fromRoutines + fromTasks
        if combined.isEmpty {
            return ["☁️", "🌅", "🎯", "💧", "🌙", "📖", "🧠", "✨", "🏠", "📋"]
        }
        // Repeat to ensure at least ~14 bubbles fly so the screen feels alive
        // even when the user picked only one or two items.
        var padded = combined
        while padded.count < 14 { padded += combined }
        return padded
    }

    private func taskEmoji(for task: DraftTask) -> String {
        switch task.suggestedEnergy {
        case .scattered: return "✨"
        case .steady:    return "🎯"
        case .locked:    return "🧠"
        case .foggy:     return "☁️"
        case .none:      return "📌"
        }
    }
}

private struct FloatingEmojiBubbles: View {
    let emojis: [String]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(emojis.enumerated()), id: \.offset) { idx, e in
                    Bubble(
                        emoji: e,
                        seed: idx,
                        width: geo.size.width,
                        height: geo.size.height
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct Bubble: View {
    let emoji: String
    let seed: Int
    let width: CGFloat
    let height: CGFloat

    @Environment(\.palette) private var palette
    @State private var rising = false

    private var xRatio: CGFloat {
        // Deterministic per-seed jitter so bubbles spread across the width
        // without re-randomizing every redraw.
        let h = (sin(Double(seed) * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1.0)
        return CGFloat(abs(h)) * 0.84 + 0.08
    }

    private var scale: CGFloat {
        let h = (sin(Double(seed) * 78.233) * 12345.678).truncatingRemainder(dividingBy: 1.0)
        return CGFloat(abs(h)) * 0.5 + 0.85
    }

    private var duration: Double {
        let h = (sin(Double(seed) * 4.5678) * 9876.54).truncatingRemainder(dividingBy: 1.0)
        return abs(h) * 3.5 + 5.5
    }

    private var delay: Double {
        Double(seed) * 0.22
    }

    private var bubbleDiameter: CGFloat { 64 * scale }

    var body: some View {
        ZStack {
            Circle()
                .fill(palette.energyFoggy.opacity(0.55))
                .frame(width: bubbleDiameter, height: bubbleDiameter)
                .shadow(color: palette.cardShadow, radius: 6, y: 2)
            Text(emoji)
                .font(.system(size: 28 * scale))
        }
        .position(
            x: xRatio * width,
            y: rising ? -bubbleDiameter : height + bubbleDiameter
        )
        .onAppear {
            withAnimation(
                .easeOut(duration: duration)
                    .delay(delay)
                    .repeatForever(autoreverses: false)
            ) {
                rising = true
            }
        }
    }
}
