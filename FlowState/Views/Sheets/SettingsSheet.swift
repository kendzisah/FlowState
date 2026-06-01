import SwiftUI
import StoreKit
import RevenueCatUI

struct SettingsSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    @State private var showCustomerCenter = false
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var accountWorking = false
    @State private var accountError: String?
    private var subs: SubscriptionManager { .shared }
    private var auth: AuthManager { .shared }

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

            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Subscription")
                subscriptionRow
            }

            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Feedback")
                rateRow
            }

            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Account")
                accountRows
            }

            Spacer(minLength: 0)

            Text("FlowState — built for brains that don't fit the schedule.")
                .font(AppFont.caption)
                .foregroundStyle(palette.textDimmed)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.bottom, 24)
        .onAppear {
            Analytics.track(.settingsOpened)
            Analytics.screen("Settings")
        }
        .onChange(of: bindable.notificationsEnabled) { _, newValue in
            Analytics.track(.notificationsToggled(value: newValue))
            Analytics.setUserProperty(key: "notifications_enabled", value: newValue)
        }
        .onChange(of: bindable.themeMode) { _, newValue in
            Analytics.track(.themeChanged(value: newValue.rawValue))
            Analytics.setUserProperty(key: "theme_mode", value: newValue.rawValue)
        }
        .presentationDetents([.fraction(0.55), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Geometry.sheetRadius)
        .presentationBackground(palette.surface)
        .sheet(isPresented: $showCustomerCenter) {
            CustomerCenterView()
                .presentationCornerRadius(Geometry.sheetRadius)
                .presentationBackground(palette.surface)
        }
        .confirmationDialog(
            "Sign out of FlowState?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) {
                Analytics.track(.signoutConfirmed)
                performSignOut()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You'll be signed back in next time you log in.")
        }
        .alert(
            "Delete account?",
            isPresented: $showDeleteConfirm
        ) {
            Button("Delete", role: .destructive) {
                Analytics.track(.deleteAccountConfirmed)
                performDeleteAccount()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently removes your account and all of its data. This can't be undone.")
        }
        .alert(
            "Couldn't finish",
            isPresented: Binding(get: { accountError != nil }, set: { if !$0 { accountError = nil } })
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(accountError ?? "")
        }
    }

    // MARK: - Account section

    @ViewBuilder
    private var accountRows: some View {
        VStack(spacing: 8) {
            if let email = auth.currentEmail {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Signed in")
                            .font(AppFont.caption)
                            .foregroundStyle(palette.textSecondary)
                        Text(email)
                            .font(AppFont.body)
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                        .fill(palette.surfaceAlt)
                )
            }

            Button { showSignOutConfirm = true } label: {
                accountRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Sign out",
                    subtitle: "Sign back in with the same email or Apple ID.",
                    destructive: false
                )
            }
            .buttonStyle(.pressable)
            .disabled(accountWorking)

            Button { showDeleteConfirm = true } label: {
                accountRow(
                    icon: "trash",
                    title: accountWorking ? "Deleting account…" : "Delete account",
                    subtitle: "Permanently remove your account and all of its data.",
                    destructive: true
                )
            }
            .buttonStyle(.pressable)
            .disabled(accountWorking)
        }
    }

    private func accountRow(icon: String, title: String, subtitle: String, destructive: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(destructive ? palette.energyScattered : palette.textPrimary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppFont.body)
                    .foregroundStyle(destructive ? palette.energyScattered : palette.textPrimary)
                Text(subtitle)
                    .font(AppFont.caption)
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                .fill(palette.surfaceAlt)
        )
    }

    private func performSignOut() {
        accountWorking = true
        _Concurrency.Task {
            await AuthManager.shared.signOut()
            await MainActor.run {
                resetLocalAccountState()
                accountWorking = false
                dismiss()
            }
        }
    }

    private func performDeleteAccount() {
        accountWorking = true
        _Concurrency.Task {
            do {
                try await AuthManager.shared.deleteAccount()
                await MainActor.run {
                    resetLocalAccountState()
                    accountWorking = false
                    dismiss()
                }
            } catch {
                AnalyticsErrorReporter.report(error, context: "settings.delete_account")
                await MainActor.run {
                    accountError = (error as? LocalizedError)?.errorDescription
                        ?? "Couldn't delete account. Try again."
                    accountWorking = false
                }
            }
        }
    }

    /// On sign-out or delete, return the user to the welcome screen and clear
    /// the profile cache so they don't see the previous user's email next time.
    private func resetLocalAccountState() {
        store.hasCompletedOnboarding = false
        store.appleUserIdentifier = nil
        store.userEmail = nil
    }

    /// Fires the StoreKit in-app review prompt. iOS rate-limits this to ~3
    /// prompts per app per year; if it's been shown too recently the tap is
    /// a silent no-op (Apple's design, not ours).
    private var rateRow: some View {
        Button {
            Analytics.track(.reviewPromptInSettingsTapped)
            requestReview()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.energySteady)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Rate FlowState")
                        .font(AppFont.body)
                        .foregroundStyle(palette.textPrimary)
                    Text("If FlowState helps your day, a rating helps others find it.")
                        .font(AppFont.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.textDimmed)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                    .fill(palette.surfaceAlt)
            )
        }
        .buttonStyle(.pressable)
    }

    @ViewBuilder
    private var subscriptionRow: some View {
        if subs.isPro {
            Button {
                Analytics.track(.subscriptionManageTapped)
                showCustomerCenter = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Manage subscription")
                            .font(AppFont.body)
                            .foregroundStyle(palette.textPrimary)
                        Text("Cancel, restore, or change plans.")
                            .font(AppFont.caption)
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textDimmed)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                        .fill(palette.surfaceAlt)
                )
            }
            .buttonStyle(.pressable)
        } else {
            Button {
                Analytics.track(.goProTapped)
                store.entitled = false
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Go Pro")
                            .font(AppFont.body)
                            .foregroundStyle(palette.textPrimary)
                        Text("Unlock all energy states and Foggy rest mode.")
                            .font(AppFont.caption)
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(palette.energySteady)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                        .fill(palette.surfaceAlt)
                )
            }
            .buttonStyle(.pressable)
        }
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
