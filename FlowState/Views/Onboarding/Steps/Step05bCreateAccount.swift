import SwiftUI

/// Hard auth gate that sits between the personalization screens and the
/// paywall. The user must successfully sign up (or sign in) here before they
/// can see pricing — every downstream piece of FlowState (subscription,
/// task sync, calendar import) needs an account.
///
/// Sign-in success (returning user noticed they already have an account)
/// skips the rest of onboarding, matching Step01's behavior.
struct Step05bCreateAccount: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void
    let onSkipOnboarding: () -> Void

    @Environment(\.palette) private var palette
    @State private var showSignInSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Create your account")
                        .font(AppFont.title)
                        .tracking(AppFont.titleTracking)
                        .foregroundStyle(palette.textPrimary)

                    Text("So your plans sync to whichever device you're on, and your subscription follows you.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                benefitsList

                AuthButtonsCluster(
                    draft: draft,
                    initialEmailMode: .signUp,
                    emailButtonTitle: "Continue with email"
                ) { signedIn in
                    // If the user toggled to "Log in" inside the email sheet
                    // and signed into an existing account, treat it like
                    // Step01's sign-in path and skip the rest of onboarding.
                    if signedIn {
                        onSkipOnboarding()
                    } else {
                        onContinue()
                    }
                }

                Button {
                    showSignInSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundStyle(palette.textSecondary)
                        Text("Log in")
                            .foregroundStyle(palette.energySteady)
                            .underline()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 36)
                }
            }
            .padding(.horizontal, Geometry.horizontalPadding)
            .padding(.top, 80)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showSignInSheet) {
            ReturningUserSignInSheet(draft: draft) {
                showSignInSheet = false
                onSkipOnboarding()
            }
            .environment(\.palette, palette)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(palette.surface)
        }
    }

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefitRow(icon: "icloud.fill", text: "Tasks and plans sync across your devices.")
            benefitRow(icon: "creditcard.fill", text: "Your subscription follows your account, not your install.")
            benefitRow(icon: "lock.shield.fill", text: "Your data stays yours. Delete the account, delete everything.")
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.energySteady)
                .frame(width: 22)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

private struct ReturningUserSignInSheet: View {
    @Bindable var draft: OnboardingDraft
    let onAuthenticated: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome back")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(AppFont.titleTracking)
                    .foregroundStyle(palette.textPrimary)
                Text("Sign in with the email or Apple ID you used before — we'll pull your plans down.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
            }

            AuthButtonsCluster(
                draft: draft,
                initialEmailMode: .signIn,
                emailButtonTitle: "Log in with email"
            ) { _ in
                onAuthenticated()
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.top, 24)
        .padding(.bottom, 24)
    }
}
