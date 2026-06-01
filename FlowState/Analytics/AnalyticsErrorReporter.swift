import Foundation
import PostHog
import CryptoKit

/// Single entry point for capturing caught errors. Every do/catch in the
/// codebase that handles a non-trivial failure routes through this so
/// every issue users encounter shows up in PostHog Errors with a
/// consistent `context` tag.
///
/// Why we don't rely on PostHog's autocapture alone: PostHog auto-captures
/// crashes (Mach/POSIX/NSException), but Swift's caught `Error` values
/// never become exceptions — they're values. We forward them manually here.
enum AnalyticsErrorReporter {

    /// Capture a Swift Error with a context tag.
    ///
    /// - Parameters:
    ///   - error: the caught error
    ///   - context: dot-separated tag like "auth.signin", "paywall.purchase".
    ///     Becomes the grouping dimension in PostHog Errors dashboards.
    ///   - properties: extra context (HTTP status, user-facing flag, etc.).
    ///     Never include PII (email, raw token, prompt text) — sanitize first.
    static func report(
        _ error: Error,
        context: String,
        properties: [String: Any] = [:],
        file: String = #file,
        line: Int = #line
    ) {
        var props: [String: Any] = [
            "context": context,
            "file": (file as NSString).lastPathComponent,
            "line": line,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
        ]
        for (k, v) in properties { props[k] = v }
        PostHogSDK.shared.captureException(error, properties: props)
    }

    /// Capture a string-described failure that doesn't have an Error value
    /// (e.g. a validation check tripped). Use sparingly — prefer real errors.
    static func reportMessage(
        _ message: String,
        context: String,
        level: String = "error",
        properties: [String: Any] = [:],
        file: String = #file,
        line: Int = #line
    ) {
        var props: [String: Any] = [
            "$exception_message": message,
            "$exception_type": "FlowStateError",
            "context": context,
            "level": level,
            "file": (file as NSString).lastPathComponent,
            "line": line,
        ]
        for (k, v) in properties { props[k] = v }
        PostHogSDK.shared.capture("$exception", properties: props)
    }

    // MARK: Redaction helpers

    /// Hash to first 8 hex chars — enough to correlate without storing raw IDs.
    static func hashed(_ id: String) -> String {
        let data = Data(id.utf8)
        let hash = SHA256.hash(data: data)
        let hex = hash.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(8))
    }

    /// Strip secret-bearing query params from URLs before recording.
    static func sanitize(url: String) -> String {
        guard var components = URLComponents(string: url) else { return url }
        let blocked: Set<String> = [
            "password", "code", "token", "access_token",
            "refresh_token", "id_token", "email", "apikey",
        ]
        components.queryItems = components.queryItems?.filter {
            !blocked.contains($0.name.lowercased())
        }
        return components.string ?? url
    }
}
