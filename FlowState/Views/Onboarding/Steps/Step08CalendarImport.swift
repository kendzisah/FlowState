import SwiftUI
import SwiftData

struct Step08CalendarImport: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @State private var importing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer().frame(height: 70)

            VStack(alignment: .leading, spacing: 6) {
                Text("Import your calendar for a quick start")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(AppFont.titleTracking)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Users who import their personal calendar plan around 46% more in their first week.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 8)

            CalendarPhoneMockup()
                .frame(maxWidth: .infinity)

            Spacer(minLength: 8)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.energyScattered)
                    .frame(maxWidth: .infinity)
            }

            OnbPrimaryButton(title: "Import calendar", inFlight: importing) {
                runImport()
            }
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.bottom, 24)
    }

    private func runImport() {
        importing = true
        errorMessage = nil
        Analytics.track(.calendarImportStarted)
        Analytics.track(.calendarPermissionRequested)
        let startedAt = Date()
        _Concurrency.Task {
            do {
                let summary = try await CalendarImportService.importNext14Days(into: modelContext)
                let latency = Int(Date().timeIntervalSince(startedAt) * 1000)
                Analytics.track(.calendarPermissionResult(granted: true))
                let eventCount = summary.inserted + summary.updated
                Analytics.track(.calendarImportSucceeded(eventCount: eventCount, latencyMs: latency))
                Analytics.track(.onboardingCalendarImported(eventCount: eventCount, granted: true))
                await MainActor.run {
                    draft.calendarGranted = true
                    importing = false
                    onContinue()
                }
            } catch CalendarImportService.ImportError.denied {
                Analytics.track(.calendarPermissionResult(granted: false))
                Analytics.track(.calendarImportFailed(reason: "denied"))
                Analytics.track(.onboardingCalendarImported(eventCount: 0, granted: false))
                AnalyticsErrorReporter.reportMessage("calendar denied", context: "onboarding.calendar.denied", level: "warning")
                await MainActor.run {
                    importing = false
                    errorMessage = "Calendar access was denied. You can enable it later in Settings."
                }
            } catch {
                Analytics.track(.calendarImportFailed(reason: "other"))
                AnalyticsErrorReporter.report(error, context: "onboarding.calendar.other")
                await MainActor.run {
                    importing = false
                    errorMessage = "Couldn't import calendar. \(error.localizedDescription)"
                }
            }
        }
    }
}

/// Phone-shaped preview showing a sample day with scheduled events and the
/// "no plans" gap rows that hint at FlowState's structured schedule view.
private struct CalendarPhoneMockup: View {
    @Environment(\.palette) private var palette

    private let phoneWidth: CGFloat = 240
    private let phoneHeight: CGFloat = 360
    private let phoneCorner: CGFloat = 38

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: phoneCorner, style: .continuous)
                .fill(palette.surface)

            VStack(spacing: 10) {
                Capsule()
                    .fill(palette.textDimmed.opacity(0.3))
                    .frame(width: 50, height: 4)
                    .padding(.top, 14)

                header

                VStack(spacing: 6) {
                    eventRow(time: "11:00 AM", title: "Focus time", duration: "1 hour", tint: palette.energyScattered)
                    gapRow(text: "1 hour → No plans")
                    eventRow(time: "1:00 PM",  title: "Lunch",      duration: "2 hours", tint: palette.energyLocked)
                    gapRow(text: "1 hour → No plans")
                    eventRow(time: "3:00 PM",  title: "Check emails", duration: "2 hours", tint: palette.energySteady)
                }
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

    private var header: some View {
        HStack {
            Image(systemName: "chevron.left")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.textDimmed)
            Spacer()
            VStack(spacing: 0) {
                Text("Monday")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
                Text("May 11th, 2026")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(palette.textDimmed)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.textDimmed)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func eventRow(time: String, title: String, duration: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(time)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(palette.textDimmed)
                .frame(width: 44, alignment: .leading)
                .padding(.top, 8)

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(tint)
                    .frame(width: 3, height: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    Text(duration)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                Circle()
                    .stroke(palette.textDimmed.opacity(0.5), lineWidth: 1)
                    .frame(width: 14, height: 14)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(palette.surfaceAlt)
            )
        }
    }

    @ViewBuilder
    private func gapRow(text: String) -> some View {
        HStack(spacing: 10) {
            Spacer().frame(width: 44)
            HStack(spacing: 6) {
                Text(text)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(palette.textDimmed)
                Spacer()
                ZStack {
                    Circle()
                        .stroke(palette.textDimmed.opacity(0.5), lineWidth: 1)
                        .frame(width: 14, height: 14)
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(palette.textDimmed)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}
