import SwiftUI
import UserNotifications

struct Step07Notifications: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void

    @Environment(\.palette) private var palette
    @State private var requesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer().frame(height: 70)

            VStack(alignment: .leading, spacing: 6) {
                Text("Never miss a task! Turn on notifications")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(AppFont.titleTracking)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Forgetful? We'll nudge you with tailored reminders so you stay on top of even the most hectic days.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 8)

            LockScreenMockup()
                .frame(maxWidth: .infinity)

            Spacer(minLength: 8)

            OnbPrimaryButton(
                title: "Enable notifications",
                inFlight: requesting,
                trailingSystemImage: "arrow.right"
            ) {
                requestPermission()
            }
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.bottom, 24)
    }

    private func requestPermission() {
        requesting = true
        _Concurrency.Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            await MainActor.run {
                draft.notificationsGranted = granted
                requesting = false
                onContinue()
            }
        }
    }
}

/// Phone-shaped lock-screen preview. Renders a black device interior with
/// time, date, and a single FlowState reminder notification.
private struct LockScreenMockup: View {
    @Environment(\.palette) private var palette

    private let phoneWidth: CGFloat = 240
    private let phoneHeight: CGFloat = 360
    private let phoneCorner: CGFloat = 38

    var body: some View {
        ZStack {
            // Device interior — always dark regardless of theme, like a real
            // lock screen.
            RoundedRectangle(cornerRadius: phoneCorner, style: .continuous)
                .fill(Color(white: 0.04))

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.black)
                    .frame(width: 90, height: 22)
                    .padding(.top, 8)

                Spacer().frame(height: 24)

                Text("Monday, May 11")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))

                Text("9:41")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(Color.white)
                    .padding(.top, -4)

                Spacer().frame(height: 28)

                NotificationCard()
                    .padding(.horizontal, 14)

                Spacer()
            }
        }
        .frame(width: phoneWidth, height: phoneHeight)
        .overlay(
            RoundedRectangle(cornerRadius: phoneCorner, style: .continuous)
                .stroke(palette.border, lineWidth: 4)
        )
        .shadow(color: palette.cardShadow, radius: 20, y: 10)
    }
}

private struct NotificationCard: View {
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(palette.energySteady)
                    .frame(width: 32, height: 32)
                Image(systemName: "bell.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.onEnergy)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("FlowState")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.black)
                    Spacer()
                    Text("now")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.black.opacity(0.5))
                }
                Text("Lunch in 10 min")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.black)
                Text("Time to refuel — a quick break keeps your focus sharp 🥗")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.7))
                    .lineLimit(3)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
    }
}
