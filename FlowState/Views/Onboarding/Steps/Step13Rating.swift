import SwiftUI
import StoreKit

struct Step13Rating: View {
    let onContinue: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.requestReview) private var requestReview
    /// Pre-filled to 5 so the visual hook matches the reference. Tapping any
    /// star still re-confirms and triggers the system review prompt.
    @State private var selectedStars: Int = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer().frame(height: 80)

            VStack(alignment: .leading, spacing: 8) {
                Text("Give a quick rating.")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(AppFont.titleTracking)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("FlowState was built for people like you.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        selectedStars = i
                        _Concurrency.Task {
                            try? await _Concurrency.Task.sleep(nanoseconds: 200_000_000)
                            await MainActor.run {
                                requestReview()
                            }
                        }
                    } label: {
                        Image(systemName: i <= selectedStars ? "star.fill" : "star")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(palette.energySteady)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Rate \(i) star\(i == 1 ? "" : "s")")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(palette.surface)
            )

            TestimonialCarousel()
                .padding(.top, 8)

            Spacer()

            OnbPrimaryButton(title: "Continue", action: onContinue)
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.bottom, 24)
    }
}

private struct Testimonial: Identifiable {
    let id = UUID()
    let stars: Int
    let body: String
    let handle: String
    let avatarInitial: String
    let avatarTint: AvatarTint

    enum AvatarTint { case steady, scattered, locked }
}

private struct TestimonialCarousel: View {
    @Environment(\.palette) private var palette
    @State private var page = 0

    private let items: [Testimonial] = [
        .init(stars: 5,
              body: "Finally an app that doesn't expect me to be at 100% all day.",
              handle: "#riley.adhd",
              avatarInitial: "R",
              avatarTint: .steady),
        .init(stars: 5,
              body: "The energy switching genuinely changed how I plan.",
              handle: "#marc.h",
              avatarInitial: "M",
              avatarTint: .scattered),
        .init(stars: 5,
              body: "Foggy mode alone is worth it. I rest without guilt now.",
              handle: "#sam.codes",
              avatarInitial: "S",
              avatarTint: .locked)
    ]

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $page) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, t in
                    card(t)
                        .padding(.horizontal, 4)
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 160)

            HStack(spacing: 6) {
                ForEach(0..<items.count, id: \.self) { i in
                    Circle()
                        .fill(i == page ? palette.energySteady : palette.border)
                        .frame(width: 6, height: 6)
                }
            }
        }
    }

    @ViewBuilder
    private func card(_ t: Testimonial) -> some View {
        VStack(alignment: .center, spacing: 10) {
            HStack(spacing: 2) {
                ForEach(0..<t.stars, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.energySteady)
                }
            }
            Text(t.body)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                Circle()
                    .fill(tintColor(t.avatarTint))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Text(t.avatarInitial)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(palette.onEnergy)
                    )
                Text(t.handle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.surface)
        )
    }

    private func tintColor(_ tint: Testimonial.AvatarTint) -> Color {
        switch tint {
        case .steady:    return palette.energySteady
        case .scattered: return palette.energyScattered
        case .locked:    return palette.energyLocked
        }
    }
}
