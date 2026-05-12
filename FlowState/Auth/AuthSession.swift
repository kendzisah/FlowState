import Foundation

/// Decoded Supabase GoTrue token response. Persisted to Keychain so users
/// don't have to sign in again on every cold launch.
struct AuthSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    /// Absolute UTC moment the access token stops being valid. Computed as
    /// `now() + expires_in` at the time the server issued it.
    let expiresAt: Date
    let userID: String
    let email: String?

    /// Refresh proactively if there's less than a minute of life left, so a
    /// 401 from upstream doesn't bubble back to the UI mid-action.
    var needsRefresh: Bool {
        expiresAt.timeIntervalSinceNow < 60
    }
}

/// The wire shape GoTrue returns on /token, /signup, /token?grant_type=*.
struct AuthTokenResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
    let user: AuthUser?

    func toSession() -> AuthSession {
        AuthSession(
            accessToken: access_token,
            refreshToken: refresh_token,
            expiresAt: Date().addingTimeInterval(TimeInterval(expires_in)),
            userID: user?.id ?? "",
            email: user?.email
        )
    }
}

struct AuthUser: Decodable {
    let id: String
    let email: String?
}

/// Decoded GoTrue error body. Server returns 4xx with this shape.
struct AuthErrorBody: Decodable {
    let error_description: String?
    let error: String?
    let msg: String?
    let message: String?

    var bestMessage: String {
        error_description ?? msg ?? message ?? error ?? "Something went wrong."
    }
}
