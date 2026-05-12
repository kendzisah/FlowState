import SwiftUI
import AuthenticationServices

/// Reusable auth UI used by Step01 (sign-in path) and Step05bCreateAccount
/// (sign-up path). Renders an Apple Sign In button + a "Continue with email"
/// button that opens the EmailAuthSheet.
///
/// The Apple flow is identical to a sign-up vs sign-in (Apple doesn't expose
/// that distinction client-side); the email flow reports back via
/// `onAuthenticated(mode)` so callers can branch (e.g., a successful sign-in
/// inside what was intended as a sign-up sheet → skip onboarding).
struct AuthButtonsCluster: View {
    @Bindable var draft: OnboardingDraft

    /// What the email sheet opens in by default — typically `.signUp` for the
    /// create-account step and `.signIn` for the welcome step's "Log in" sheet.
    var initialEmailMode: EmailAuthSheet.Mode = .signUp

    /// Label on the email button. Defaults to "Continue with email"; the
    /// welcome screen's sign-in sheet uses "Log in with email".
    var emailButtonTitle: String = "Continue with email"

    /// Called on any successful auth. `signedIn` is true when the user
    /// followed a sign-in path (returning user) and false for sign-up.
    /// Apple auth always reports `signedIn: false` since the SDK can't tell
    /// us whether the user is new; callers that need to differentiate should
    /// use Supabase user metadata instead.
    var onAuthenticated: (_ signedIn: Bool) -> Void

    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    @State private var showEmailSheet = false
    @State private var appleNonce: (raw: String, hashed: String)?
    @State private var appleErrorText: String?

    var body: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.continue) { request in
                let pair = AuthManager.newAppleNonce()
                self.appleNonce = pair
                request.requestedScopes = [.fullName, .email]
                request.nonce = pair.hashed
            } onCompletion: { result in
                handleAppleCompletion(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: Geometry.minTapTarget)
            .clipShape(RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous))

            OnbSecondaryButton(title: emailButtonTitle, systemImage: "envelope") {
                showEmailSheet = true
            }

            if let appleErrorText {
                Text(appleErrorText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.energyScattered)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .sheet(isPresented: $showEmailSheet) {
            EmailAuthSheet(draft: draft, initialMode: initialEmailMode) { resolvedMode in
                showEmailSheet = false
                onAuthenticated(resolvedMode == .signIn)
            }
            .environment(\.palette, palette)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(palette.surface)
        }
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = appleNonce?.raw else {
                appleErrorText = "Apple sign-in didn't return a valid token."
                return
            }
            draft.appleUserIdentifier = cred.user
            if let email = cred.email { draft.userEmail = email }

            _Concurrency.Task {
                do {
                    try await AuthManager.shared.signInWithApple(idToken: idToken, nonce: nonce)
                    if draft.userEmail == nil {
                        draft.userEmail = AuthManager.shared.currentEmail
                    }
                    onAuthenticated(false)
                } catch {
                    appleErrorText = (error as? LocalizedError)?.errorDescription
                        ?? "Couldn't finish Apple sign-in. Try email instead."
                }
            }
        case .failure(let error):
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                return
            }
            appleErrorText = error.localizedDescription
        }
    }
}
