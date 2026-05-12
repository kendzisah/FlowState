import SwiftUI

/// Welcome / entry-point screen. Has two paths:
///   • "Get started" → advances through the normal onboarding flow. The user
///     creates an account at a later, dedicated step (Step05bCreateAccount).
///   • "Already have an account? Sign in" → opens an Apple/Email auth sheet.
///     Successful auth skips the rest of onboarding entirely; the user lands
///     on the paywall if they're not entitled, or on home if they are.
struct Step01Welcome: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void
    let onSkipOnboarding: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    @State private var showSignInSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HeroPanel()
                .frame(maxHeight: .infinity)

            VStack(spacing: 12) {
                OnbPrimaryButton(title: "Get started") {
                    onContinue()
                }

                Button {
                    if AuthManager.shared.isAuthenticated {
                        // Already signed in (session restored from Keychain).
                        // Skip onboarding directly.
                        onSkipOnboarding()
                    } else {
                        showSignInSheet = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundStyle(palette.textSecondary)
                        Text("Sign in")
                            .foregroundStyle(palette.energySteady)
                            .underline()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 36)
                }
            }
            .padding(.horizontal, Geometry.horizontalPadding)
            .padding(.bottom, 28)
        }
        .sheet(isPresented: $showSignInSheet) {
            SignInSheet(draft: draft) {
                showSignInSheet = false
                onSkipOnboarding()
            }
            .environment(\.palette, palette)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(palette.surface)
        }
    }
}

/// Sheet body for the returning-user sign-in path. Apple + Email log-in
/// (no sign-up toggle exposed — users who want to sign up should back out
/// and use "Get started" instead).
private struct SignInSheet: View {
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
                Text("Sign in with Apple or your email — we'll pull your plans down.")
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

private struct HeroPanel: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                ForEach(0..<2, id: \.self) { i in
                    DriftingFogBlob(
                        size: 220,
                        color: palette.energySteady,
                        opacity: 0.26,
                        phase: Double(i) / 2.0,
                        durationSeconds: 22 + Double(i) * 4
                    )
                }
                HStack(spacing: 18) {
                    ForEach([EnergyLevel.scattered, .steady, .locked], id: \.self) { level in
                        Image(systemName: level.iconName)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(level.color(in: palette))
                    }
                }
            }
            .frame(height: 200)

            VStack(spacing: 12) {
                Text("FlowState")
                    .font(AppFont.title)
                    .tracking(AppFont.titleTracking)
                    .foregroundStyle(palette.textPrimary)
                Text("Your day, planned around your energy.")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}
