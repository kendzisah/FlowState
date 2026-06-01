import SwiftUI

/// Email + password auth sheet. Three modes:
///   • signUp — new account; submits to AuthManager.signUp
///   • signIn — returning user; submits to AuthManager.signIn
///   • reset  — sends a reset link via AuthManager.requestPasswordReset
///
/// On success, drops `userEmail` into the onboarding draft (for personalization
/// later) and calls `onAuthenticated`. The caller decides what comes next in
/// the onboarding flow.
struct EmailAuthSheet: View {
    enum Mode: Equatable {
        case signUp
        case signIn
        case reset
    }

    @Bindable var draft: OnboardingDraft
    var initialMode: Mode = .signUp
    /// Fires on successful sign-up or sign-in. The `Mode` tells the caller
    /// which path succeeded — useful when sign-up and sign-in should advance
    /// to different places (e.g., sign-in skips onboarding, sign-up doesn't).
    let onAuthenticated: (Mode) -> Void

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .signUp
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorText: String?
    @State private var resetSent = false

    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool

    private var isEmailValid: Bool {
        let t = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.contains("@") && t.contains(".") && t.count >= 5
    }

    private var isPasswordValid: Bool {
        password.count >= 8
    }

    private var canSubmit: Bool {
        switch mode {
        case .signUp, .signIn: return isEmailValid && isPasswordValid && !isWorking
        case .reset:           return isEmailValid && !isWorking
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            tabSwitcher

            VStack(alignment: .leading, spacing: 12) {
                emailField
                if mode != .reset {
                    passwordField
                }
                if mode == .signIn {
                    forgotPasswordLink
                }
                if let errorText {
                    Text(errorText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.energyScattered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if mode == .reset && resetSent {
                    Text("Check your inbox for a password-reset link.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.captionPulse)
                }
            }

            Spacer(minLength: 0)

            OnbPrimaryButton(
                title: ctaLabel,
                enabled: canSubmit,
                inFlight: isWorking
            ) {
                submit()
            }
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .onAppear {
            mode = initialMode
            emailFocused = true
        }
        .animation(.easeInOut(duration: 0.18), value: mode)
        .animation(.easeInOut(duration: 0.18), value: errorText)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headlineForMode)
                .font(.system(size: 24, weight: .bold))
                .tracking(AppFont.titleTracking)
                .foregroundStyle(palette.textPrimary)
            Text(subheadForMode)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var headlineForMode: String {
        switch mode {
        case .signUp: return "Create your account"
        case .signIn: return "Welcome back"
        case .reset:  return "Reset password"
        }
    }

    private var subheadForMode: String {
        switch mode {
        case .signUp: return "Use your email so your plans sync across devices."
        case .signIn: return "Sign in with the email you used before."
        case .reset:  return "We'll email you a link to set a new password."
        }
    }

    // MARK: - Tab switcher

    private var tabSwitcher: some View {
        HStack(spacing: 8) {
            tabChip(.signUp, label: "Sign up")
            tabChip(.signIn, label: "Log in")
        }
        .opacity(mode == .reset ? 0.5 : 1)
        .disabled(mode == .reset)
    }

    private func tabChip(_ target: Mode, label: String) -> some View {
        let on = mode == target
        return Button {
            mode = target
            errorText = nil
            resetSent = false
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(on ? palette.onEnergy : palette.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(on ? palette.energySteady : palette.surfaceAlt)
                )
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Fields

    private var emailField: some View {
        TextField("you@example.com", text: $email)
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .focused($emailFocused)
            .submitLabel(mode == .reset ? .send : .next)
            .onSubmit {
                if mode != .reset { passwordFocused = true }
                else if canSubmit { submit() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                    .fill(palette.surfaceAlt)
            )
            .foregroundStyle(palette.textPrimary)
    }

    private var passwordField: some View {
        SecureField("Password (8+ characters)", text: $password)
            .textContentType(mode == .signUp ? .newPassword : .password)
            .focused($passwordFocused)
            .submitLabel(.go)
            .onSubmit { if canSubmit { submit() } }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                    .fill(palette.surfaceAlt)
            )
            .foregroundStyle(palette.textPrimary)
    }

    private var forgotPasswordLink: some View {
        Button {
            mode = .reset
            errorText = nil
            resetSent = false
        } label: {
            Text("Forgot password?")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.energySteady)
                .underline()
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - CTA

    private var ctaLabel: String {
        if isWorking {
            switch mode {
            case .signUp: return "Creating account…"
            case .signIn: return "Signing in…"
            case .reset:  return "Sending…"
            }
        }
        switch mode {
        case .signUp: return "Create account"
        case .signIn: return "Log in"
        case .reset:  return resetSent ? "Sent" : "Send reset link"
        }
    }

    // MARK: - Submit

    private func submit() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        errorText = nil
        isWorking = true

        _Concurrency.Task {
            do {
                switch mode {
                case .signUp:
                    try await AuthManager.shared.signUp(email: trimmedEmail, password: password)
                    draft.userEmail = trimmedEmail
                    Analytics.track(.onboardingAccountCreated(method: "email"))
                    onAuthenticated(.signUp)
                case .signIn:
                    try await AuthManager.shared.signIn(email: trimmedEmail, password: password)
                    draft.userEmail = trimmedEmail
                    onAuthenticated(.signIn)
                case .reset:
                    try await AuthManager.shared.requestPasswordReset(email: trimmedEmail)
                    resetSent = true
                }
            } catch {
                errorText = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
                // Auth-flow events already fired via AuthManager.signUp/signIn
                // failure tracking — but capture the underlying error too.
                AnalyticsErrorReporter.report(error, context: "onboarding.auth.email", properties: ["mode": String(describing: mode)])
            }
            isWorking = false
        }
    }
}
