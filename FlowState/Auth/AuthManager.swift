import Foundation
import Observation
import CryptoKit

enum AuthError: LocalizedError {
    case missingConfig
    case network(Error)
    case server(message: String, status: Int)
    case decoding
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .missingConfig:        return "Auth isn't configured. Check Secrets.xcconfig."
        case .network(let e):       return e.localizedDescription
        case .server(let msg, _):   return msg
        case .decoding:             return "Couldn't read the server's response."
        case .notAuthenticated:     return "You're not signed in."
        }
    }
}

/// Observable wrapper around Supabase GoTrue's REST API.
///
/// State:
///   • `session` is the source of truth for "is the user signed in".
///   • Persisted to Keychain on every change; restored on cold launch via
///     `restore()` (called from FlowStateApp init).
///   • Refresh-token rotation happens automatically before any authenticated
///     request — call `accessTokenForRequest()` to get a fresh token.
///
/// Network model: direct REST calls. We deliberately don't pull in the
/// Supabase Swift SDK so the binary stays small and the surface is easy to
/// audit. GoTrue's API is stable.
@MainActor
@Observable
final class AuthManager {
    static let shared = AuthManager()

    private(set) var session: AuthSession?
    private(set) var isRestoring: Bool = true

    var isAuthenticated: Bool { session != nil }
    var currentUserID: String? { session?.userID }
    var currentEmail: String? { session?.email }

    private init() {}

    // MARK: - Config

    private var supabaseURL: URL? {
        guard let raw = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              !raw.isEmpty, !raw.contains("$(") else { return nil }
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return URL(string: trimmed)
    }

    private var publishableKey: String? {
        guard let k = Bundle.main.infoDictionary?["SUPABASE_PUBLISHABLE_KEY"] as? String,
              !k.isEmpty, !k.contains("$(") else { return nil }
        return k
    }

    // MARK: - Lifecycle

    /// Loads any persisted session from Keychain and proactively refreshes
    /// if the access token has less than 60s of life left. Call once at app
    /// launch.
    func restore() async {
        defer { isRestoring = false }
        guard let stored = AuthKeychain.load() else {
            session = nil
            return
        }
        session = stored
        if stored.needsRefresh {
            try? await refreshIfNeeded()
        }
        // Pull RC's cached CustomerInfo so `store.entitled` is correct before
        // `isRestoring` flips to false. Without this, the route gate would
        // briefly see stale entitlement and flash the paywall for returning
        // subscribers on cold launch.
        await SubscriptionManager.shared.refreshFromCache()
    }

    // MARK: - Public actions

    func signUp(email: String, password: String) async throws {
        Analytics.track(.signupStarted(method: "email"))
        do {
            let body: [String: Any] = ["email": email, "password": password]
            let response: AuthTokenResponse = try await postJSON("/auth/v1/signup", body: body)
            try await persist(response.toSession(), method: "email", isNewAccount: true)
        } catch {
            let (reason, status) = Self.describe(error)
            Analytics.track(.signupFailed(method: "email", reason: reason, httpStatus: status))
            AnalyticsErrorReporter.report(error, context: "auth.signup", properties: ["method": "email"])
            throw error
        }
    }

    func signIn(email: String, password: String) async throws {
        Analytics.track(.signinStarted(method: "email"))
        do {
            let body: [String: Any] = ["email": email, "password": password]
            let response: AuthTokenResponse = try await postJSON("/auth/v1/token?grant_type=password", body: body)
            try await persist(response.toSession(), method: "email", isNewAccount: false)
        } catch {
            let (reason, status) = Self.describe(error)
            Analytics.track(.signinFailed(method: "email", reason: reason, httpStatus: status))
            AnalyticsErrorReporter.report(error, context: "auth.signin", properties: ["method": "email"])
            throw error
        }
    }

    /// Exchange an Apple identity token for a Supabase session. The `nonce`
    /// must be the *unhashed* value matching the SHA-256 hash passed to
    /// `ASAuthorizationAppleIDRequest.nonce`. Supabase verifies the JWT
    /// signature using Apple's published keys and the nonce.
    func signInWithApple(idToken: String, nonce: String) async throws {
        Analytics.track(.signinStarted(method: "apple"))
        do {
            let body: [String: Any] = [
                "provider": "apple",
                "id_token": idToken,
                "nonce": nonce,
            ]
            let response: AuthTokenResponse = try await postJSON("/auth/v1/token?grant_type=id_token", body: body)
            // Apple flow can be either first-time or returning — Supabase
            // upserts. We track as signin; if the user was new, Supabase
            // emits a different created_at — analyzers can derive net-new
            // users from that. Avoids needing a second round-trip.
            try await persist(response.toSession(), method: "apple", isNewAccount: false)
        } catch {
            let (reason, status) = Self.describe(error)
            Analytics.track(.signinFailed(method: "apple", reason: reason, httpStatus: status))
            AnalyticsErrorReporter.report(error, context: "auth.signin", properties: ["method": "apple"])
            throw error
        }
    }

    func requestPasswordReset(email: String) async throws {
        let body: [String: Any] = ["email": email]
        try await postEmpty("/auth/v1/recover", body: body)
    }

    func signOut() async {
        Analytics.track(.signout)
        if let token = session?.accessToken {
            // Best-effort revoke. If the network is down, we still clear local.
            _ = try? await postEmpty("/auth/v1/logout", body: [:], bearerToken: token)
        }
        await clear()
    }

    /// Calls our `account-delete` edge function, which uses the service role
    /// to remove the user from `auth.users`. The user's auth row + any tables
    /// referencing it via `ON DELETE CASCADE` (none in v1) are wiped. We
    /// then clear local state.
    func deleteAccount() async throws {
        guard let session else { throw AuthError.notAuthenticated }
        Analytics.track(.accountDeleted)
        try await callEdgeFunction(
            name: "account-delete",
            body: [:],
            bearerToken: session.accessToken
        )
        await clear()
    }

    /// Returns a fresh access token, refreshing the session first if needed.
    /// Throws `notAuthenticated` if there's no session.
    func accessTokenForRequest() async throws -> String {
        guard let session else { throw AuthError.notAuthenticated }
        if session.needsRefresh {
            try await refreshIfNeeded()
        }
        return self.session?.accessToken ?? session.accessToken
    }

    // MARK: - Apple nonce helpers

    /// Generates a random `(raw, sha256Hex)` nonce pair. Pass the SHA-256 hex
    /// to `ASAuthorizationAppleIDRequest.nonce` and keep the raw value to
    /// send to `signInWithApple(idToken:nonce:)`.
    static func newAppleNonce() -> (raw: String, hashed: String) {
        let raw = randomNonceString()
        let hashed = sha256Hex(raw)
        return (raw, hashed)
    }

    private static func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        for byte in bytes {
            result.append(charset[Int(byte) % charset.count])
        }
        return result
    }

    private static func sha256Hex(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Internal

    private func refreshIfNeeded() async throws {
        guard let stored = session else { return }
        do {
            let body: [String: Any] = ["refresh_token": stored.refreshToken]
            let response: AuthTokenResponse = try await postJSON("/auth/v1/token?grant_type=refresh_token", body: body)
            try await persist(response.toSession(), method: nil, isNewAccount: false)
        } catch {
            let (reason, _) = Self.describe(error)
            Analytics.track(.sessionRefreshFailed(reason: reason))
            AnalyticsErrorReporter.report(error, context: "auth.refresh")
            throw error
        }
    }

    /// Saves the session to Keychain, then `await`s RC.logIn so the new
    /// customer info is reflected in `store.entitled` before this returns.
    /// Callers can rely on the route gate seeing the correct entitlement
    /// immediately, with no paywall-flash for returning subscribers.
    ///
    /// `method` is the auth method used (email/apple) for analytics. Pass
    /// `nil` from refresh paths where there's no fresh signup/signin event
    /// to emit.
    private func persist(_ next: AuthSession, method: String?, isNewAccount: Bool) async throws {
        try AuthKeychain.save(next)
        session = next
        await SubscriptionManager.shared.logIn(userID: next.userID)

        // Identify to analytics — links anonymous device events to user.
        // Pulled from MainActor-isolated AppStore.shared if it existed;
        // since AppStore is currently an instance owned by FlowStateApp,
        // we identify with minimal traits here and the app re-identifies
        // with full traits on the next .task in FlowStateApp / RootView.
        Analytics.identify(userID: next.userID, traits: ["user_id": next.userID])
        if let method {
            if isNewAccount {
                Analytics.track(.signupCompleted(method: method, userID: next.userID))
            } else {
                Analytics.track(.signinCompleted(method: method, userID: next.userID))
            }
        }
    }

    /// Clears the local session and disconnects from RC. Awaits RC.logOut so
    /// `store.entitled` is settled before the route gate re-evaluates.
    private func clear() async {
        AuthKeychain.clear()
        session = nil
        await SubscriptionManager.shared.logOut()
        Analytics.reset()
        // Drop the prior user's reminders so a new sign-in doesn't see
        // notifications scheduled against another account's data.
        NotificationManager.cancelAllRoutineReminders()
        NotificationManager.cancelAllTaskReminders()
    }

    /// Maps an Error (typically AuthError) into a (reason, optional HTTP status)
    /// pair suitable for analytics. Strips secret-bearing strings.
    private static func describe(_ error: Error) -> (String, Int?) {
        if let auth = error as? AuthError {
            switch auth {
            case .missingConfig:            return ("missing_config", nil)
            case .network(let inner):       return ("network: \(inner.localizedDescription)", nil)
            case .server(let msg, let s):   return ("server: \(msg.prefix(120))", s)
            case .decoding:                 return ("decoding", nil)
            case .notAuthenticated:         return ("not_authenticated", nil)
            }
        }
        return (String(describing: error).prefix(120).description, nil)
    }

    // MARK: - HTTP

    /// Appends `path` (which may include a `?query=...` suffix) onto `base`,
    /// preserving the query string. `URL.appendingPathComponent` percent-encodes
    /// `?` into `%3F`, which silently breaks every GoTrue endpoint that relies
    /// on `?grant_type=...` (Apple sign-in, password sign-in, refresh).
    private static func buildURL(base: URL, path: String) -> URL? {
        let stripped = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let parts = stripped.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let pathOnly = String(parts[0])
        let query = parts.count > 1 ? String(parts[1]) : nil

        var url = base
        for segment in pathOnly.split(separator: "/") {
            url.appendPathComponent(String(segment))
        }
        guard let query, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.percentEncodedQuery = query
        return components.url
    }

    private func postJSON<T: Decodable>(_ path: String, body: [String: Any], bearerToken: String? = nil) async throws -> T {
        let data = try await rawPOST(path, body: body, bearerToken: bearerToken)
        guard let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            throw AuthError.decoding
        }
        return decoded
    }

    private func postEmpty(_ path: String, body: [String: Any], bearerToken: String? = nil) async throws {
        _ = try await rawPOST(path, body: body, bearerToken: bearerToken)
    }

    private func rawPOST(_ path: String, body: [String: Any], bearerToken: String?) async throws -> Data {
        guard let base = supabaseURL, let key = publishableKey else {
            throw AuthError.missingConfig
        }
        guard let url = Self.buildURL(base: base, path: path) else {
            throw AuthError.missingConfig
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(bearerToken ?? key)", forHTTPHeaderField: "Authorization")
        request.httpBody = body.isEmpty ? Data("{}".utf8) : (try JSONSerialization.data(withJSONObject: body))
        request.timeoutInterval = 30

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            AnalyticsErrorReporter.report(error, context: "auth.network", properties: [
                "url": AnalyticsErrorReporter.sanitize(url: url.absoluteString),
            ])
            throw AuthError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            AnalyticsErrorReporter.reportMessage("Non-HTTP response", context: "auth.decoding")
            throw AuthError.decoding
        }
        if !(200...299).contains(http.statusCode) {
            let parsed = try? JSONDecoder().decode(AuthErrorBody.self, from: data)
            let message = parsed?.bestMessage ?? String(data: data, encoding: .utf8) ?? "Server error"
            throw AuthError.server(message: message, status: http.statusCode)
        }
        return data
    }

    private func callEdgeFunction(name: String, body: [String: Any], bearerToken: String) async throws {
        guard let base = supabaseURL, let key = publishableKey else {
            throw AuthError.missingConfig
        }
        guard let url = Self.buildURL(base: base, path: "functions/v1/\(name)") else {
            throw AuthError.missingConfig
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = body.isEmpty ? Data("{}".utf8) : (try JSONSerialization.data(withJSONObject: body))
        request.timeoutInterval = 30

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            AnalyticsErrorReporter.report(error, context: "auth.edge.\(name)", properties: [
                "url": AnalyticsErrorReporter.sanitize(url: url.absoluteString),
            ])
            throw AuthError.network(error)
        }

        guard let http = response as? HTTPURLResponse else { throw AuthError.decoding }
        if !(200...299).contains(http.statusCode) {
            let parsed = try? JSONDecoder().decode(AuthErrorBody.self, from: data)
            let message = parsed?.bestMessage ?? String(data: data, encoding: .utf8) ?? "Server error"
            throw AuthError.server(message: message, status: http.statusCode)
        }
    }
}
