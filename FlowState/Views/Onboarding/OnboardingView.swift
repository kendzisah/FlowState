import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var palette

    enum Step: Int, CaseIterable {
        case welcome, problem, preview, paywall
    }

    @State private var step: Step = .welcome

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? palette.energySteady : palette.surfaceAlt)
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, Geometry.horizontalPadding)
            .padding(.top, 12)

            Group {
                switch step {
                case .welcome: WelcomeStep(onNext: advance)
                case .problem: ProblemStep(onNext: advance)
                case .preview: EnergyPreviewStep(onNext: advance)
                case .paywall: PaywallView(onStartTrial: completeOnboarding)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal:   .move(edge: .leading).combined(with: .opacity)
            ))
        }
    }

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.32)) {
            step = next
        }
    }

    private func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.32)) {
            store.entitled = true
            store.hasCompletedOnboarding = true
        }
    }
}

private struct WelcomeStep: View {
    var onNext: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            HStack(spacing: 18) {
                ForEach([EnergyLevel.scattered, .steady, .locked], id: \.self) { level in
                    Image(systemName: level.iconName)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(level.color(in: palette))
                }
            }

            VStack(spacing: 14) {
                Text("FlowState")
                    .font(AppFont.title)
                    .tracking(AppFont.titleTracking)
                    .foregroundStyle(palette.textPrimary)
                Text("Tasks that match your brain right now.")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Geometry.horizontalPadding)

            Spacer()

            primaryButton("Get started", action: onNext, palette: palette)
                .padding(.horizontal, Geometry.horizontalPadding)
                .padding(.bottom, 32)
        }
    }
}

private struct ProblemStep: View {
    var onNext: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            Text("Most apps assume\nyou can do anything\nat any time.")
                .font(.system(size: 30, weight: .bold))
                .tracking(AppFont.titleTracking)
                .foregroundStyle(palette.textPrimary)

            Text("Your brain knows that's not true. Some hours you can refactor a system. Some hours you can barely answer an email. Some hours you can't even read.")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(palette.textSecondary)

            Text("FlowState lets you tell it which one you are. The list rearranges itself.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.textPrimary)

            Spacer()

            primaryButton("Show me how", action: onNext, palette: palette)
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.bottom, 32)
    }
}

private struct EnergyPreviewStep: View {
    var onNext: () -> Void
    @Environment(\.palette) private var palette

    private struct Sample {
        let level: EnergyLevel
        let task: String
    }
    private let samples: [Sample] = [
        Sample(level: .foggy,     task: "Drink a glass of water"),
        Sample(level: .scattered, task: "Reply to a few emails"),
        Sample(level: .steady,    task: "Outline next week's plan"),
        Sample(level: .locked,    task: "Refactor the auth module")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 16)

            Text("Four energy states.\nOne small action each.")
                .font(.system(size: 26, weight: .bold))
                .tracking(AppFont.titleTracking)
                .foregroundStyle(palette.textPrimary)

            VStack(spacing: 10) {
                ForEach(samples, id: \.level) { s in
                    HStack(spacing: 12) {
                        Image(systemName: s.level.iconName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(palette.onEnergy)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.level.shortLabel)
                                .font(.system(size: 14, weight: .bold))
                                .tracking(0.4)
                                .foregroundStyle(palette.onEnergy)
                            Text(s.task)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(palette.onEnergy.opacity(0.85))
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                            .fill(s.level.color(in: palette))
                    )
                }
            }

            Spacer()

            primaryButton("Continue", action: onNext, palette: palette)
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.bottom, 32)
    }
}

@ViewBuilder
private func primaryButton(_ title: String, action: @escaping () -> Void, palette: Palette) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(palette.onEnergy)
            .frame(maxWidth: .infinity, minHeight: Geometry.minTapTarget)
            .background(
                RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                    .fill(palette.energySteady)
            )
    }
    .buttonStyle(.pressable)
}
