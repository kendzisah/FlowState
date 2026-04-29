import SwiftUI

struct SettingsSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var bindable = store

        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings")
                    .font(AppFont.title)
                    .tracking(AppFont.titleTracking)
                    .foregroundStyle(palette.textPrimary)
                Text("Tune the parts of the app that get in your way.")
                    .font(AppFont.body)
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Theme")
                themePicker
            }

            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Notifications")
                Toggle(isOn: $bindable.notificationsEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Session-complete notifications")
                            .font(AppFont.body)
                            .foregroundStyle(palette.textPrimary)
                        Text("A gentle ping when a countdown ends. No streaks, no shame.")
                            .font(AppFont.caption)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .tint(palette.energySteady)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                        .fill(palette.surfaceAlt)
                )
            }

            Spacer(minLength: 0)

            Text("FlowState — built for brains that don't fit the schedule.")
                .font(AppFont.caption)
                .foregroundStyle(palette.textDimmed)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.bottom, 24)
        .presentationDetents([.fraction(0.55), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Geometry.sheetRadius)
        .presentationBackground(palette.surface)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(palette.textSecondary)
    }

    private var themePicker: some View {
        HStack(spacing: 10) {
            ForEach(ThemeMode.allCases, id: \.self) { mode in
                themeChip(mode)
            }
        }
    }

    private func themeChip(_ mode: ThemeMode) -> some View {
        let on = store.themeMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                store.themeMode = mode
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: themeIcon(mode))
                    .font(.system(size: 18, weight: .semibold))
                Text(themeLabel(mode))
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(on ? palette.onEnergy : palette.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Geometry.minTapTarget)
            .background(
                RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                    .fill(on ? palette.energySteady : palette.surfaceAlt)
            )
        }
        .buttonStyle(.pressable)
    }

    private func themeIcon(_ mode: ThemeMode) -> String {
        switch mode {
        case .system: return "circle.lefthalf.filled"
        case .dark:   return "moon.fill"
        case .light:  return "sun.max.fill"
        }
    }

    private func themeLabel(_ mode: ThemeMode) -> String {
        switch mode {
        case .system: return "System"
        case .dark:   return "Dark"
        case .light:  return "Light"
        }
    }
}
