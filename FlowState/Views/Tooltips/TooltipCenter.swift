import SwiftUI

/// Tracks which first-time tooltips a user has dismissed. Persistence is per
/// install (UserDefaults) — clean reinstall or new account on the same device
/// will re-show the tour.
///
/// Tooltips are identified by a stable string ID. Adding a new tooltip in the
/// app is just calling `.firstTimeTooltip(id:title:body:)` somewhere new —
/// the dismissal state is keyed by `id`.
@MainActor
enum TooltipCenter {
    private static let keyPrefix = "tooltip.seen."

    static func hasSeen(_ id: String) -> Bool {
        UserDefaults.standard.bool(forKey: keyPrefix + id)
    }

    static func markSeen(_ id: String) {
        UserDefaults.standard.set(true, forKey: keyPrefix + id)
    }
}

extension View {
    /// Presents a one-time onboarding callout the first time this view appears
    /// for a given `id`. The callout is a centered card explaining what the
    /// screen does; dismissing it persists "seen" so it never reappears for
    /// this user on this device.
    func firstTimeTooltip(id: String, title: String, body: String) -> some View {
        modifier(FirstTimeTooltipModifier(id: id, title: title, message: body))
    }
}

private struct FirstTimeTooltipModifier: ViewModifier {
    let id: String
    let title: String
    let message: String

    @State private var presented: Bool = false
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !TooltipCenter.hasSeen(id), !presented else { return }
                // Delay so the underlying view has settled before the
                // tooltip animates in. Less jarring than firing instantly.
                _Concurrency.Task {
                    try? await _Concurrency.Task.sleep(nanoseconds: 350_000_000)
                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.25)) {
                            presented = true
                        }
                    }
                }
            }
            .overlay {
                if presented {
                    TooltipOverlay(title: title, message: message) {
                        TooltipCenter.markSeen(id)
                        withAnimation(.easeIn(duration: 0.18)) {
                            presented = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(99)
                }
            }
    }
}

private struct TooltipOverlay: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .tracking(AppFont.titleTracking)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(message)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onDismiss) {
                    Text("Got it")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.onEnergy)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                                .fill(palette.energySteady)
                        )
                }
                .buttonStyle(.pressable)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(palette.surface)
                    .shadow(color: palette.cardShadow, radius: 24, y: 12)
            )
            .padding(.horizontal, 32)
        }
    }
}
