import Foundation
import RevenueCat

enum OpenAIClientError: Error {
    case missingProxyConfig         // SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY not wired
    case missingUserIdentity        // RevenueCat appUserID unavailable
    case http(Int, String)
    case decoding
    case network(Error)
    case quotaExceeded(resetsAt: Date)
}

/// Thin client for the FlowState AI proxy (Supabase Edge Function `ai-proxy`).
///
/// Reads `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` from Info.plist
/// (passed through Secrets.xcconfig). The OpenAI key lives only on the server
/// — we never ship it. Every request carries `X-User-ID` (RevenueCat's
/// stable appUserID) so the proxy can enforce a per-user daily cap.
///
/// On HTTP 429 (`daily_quota_exceeded`), updates `AIQuotaState.shared` and
/// throws `OpenAIClientError.quotaExceeded(resetsAt:)`. Callers can match on
/// that case to short-circuit retries and surface the lock to the UI.
@MainActor
struct OpenAIClient {
    private let timeoutSeconds: TimeInterval = 30
    private let model = "gpt-4o-mini"

    private var proxyEndpoint: URL? {
        guard let raw = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              !raw.isEmpty,
              !raw.contains("$(") else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(trimmed)/functions/v1/ai-proxy")
    }

    private var publishableKey: String? {
        guard let k = Bundle.main.infoDictionary?["SUPABASE_PUBLISHABLE_KEY"] as? String,
              !k.isEmpty,
              !k.contains("$(") else { return nil }
        return k
    }

    /// Generic JSON-mode chat request. Returns the raw assistant content
    /// string from OpenAI; caller is responsible for decoding it.
    func chatJSON(systemPrompt: String, userPrompt: String, temperature: Double = 0.4) async throws -> String {
        // Short-circuit if the device cache already knows we're locked out.
        // Saves a round trip + makes the lock instant after the first 429.
        if let resetsAt = AIQuotaState.shared.resetsAt, resetsAt > Date() {
            throw OpenAIClientError.quotaExceeded(resetsAt: resetsAt)
        }

        guard let proxyEndpoint, let publishableKey else {
            throw OpenAIClientError.missingProxyConfig
        }

        let userID = Purchases.shared.appUserID
        guard !userID.isEmpty else {
            throw OpenAIClientError.missingUserIdentity
        }

        let body: [String: Any] = [
            "systemPrompt": systemPrompt,
            "userPrompt": userPrompt,
            "temperature": temperature,
            "model": model,
            "responseFormat": "json_object",
        ]

        var request = URLRequest(url: proxyEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue(userID, forHTTPHeaderField: "X-User-ID")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = timeoutSeconds

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw OpenAIClientError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw OpenAIClientError.decoding
        }

        if http.statusCode == 429 {
            let resetsAt = parseResetsAt(from: data, response: http)
            AIQuotaState.shared.markQuotaExceeded(resetsAt: resetsAt)
            throw OpenAIClientError.quotaExceeded(resetsAt: resetsAt)
        }

        if !(200...299).contains(http.statusCode) {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIClientError.http(http.statusCode, bodyString)
        }

        struct Envelope: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }

        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              let content = envelope.choices.first?.message.content else {
            throw OpenAIClientError.decoding
        }
        return content
    }

    /// Onboarding's task-extraction request. Thin wrapper around `chatJSON`.
    func extractTasks(from userInput: String) async throws -> String {
        let systemPrompt = """
        You are FlowState, a calm planning assistant for ADHD users. The user will paste \
        a free-form list of things on their plate this week. Extract distinct, concrete \
        tasks. Keep them short (3–8 words each). Suggest an energy tag for each: \
        "scattered" (low focus, e.g. emails, errands), "steady" (medium focus, e.g. \
        planning, light work), or "locked" (high focus, e.g. deep work, learning). \
        Never use "foggy" — that's a rest state, not a task tag. Categorize each task: \
        "Work", "Personal", "Errand", "Social", or "Home". Return ONLY a JSON object of \
        the form: {"tasks": [{"title": "...", "category": "...", "suggestedEnergy": "..."}]}.
        """
        return try await chatJSON(systemPrompt: systemPrompt, userPrompt: userInput)
    }

    private func parseResetsAt(from data: Data, response: HTTPURLResponse) -> Date {
        if let header = response.value(forHTTPHeaderField: "X-Quota-Resets-At"),
           let date = Self.isoFormatter.date(from: header) {
            return date
        }
        struct QuotaError: Decodable { let resets_at: String? }
        if let parsed = try? JSONDecoder().decode(QuotaError.self, from: data),
           let iso = parsed.resets_at,
           let date = Self.isoFormatter.date(from: iso) {
            return date
        }
        // Conservative fallback: tomorrow's UTC midnight.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return calendar.startOfDay(for: tomorrow)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

struct TaskExtractionResponse: Decodable {
    struct Item: Decodable {
        let title: String
        let category: String
        let suggestedEnergy: String
    }
    let tasks: [Item]
}

@MainActor
enum TaskExtractor {
    /// Tries the AI extractor; falls back to a rule-based splitter on any
    /// non-quota failure so the user is never blocked. Quota errors are
    /// re-thrown so the chat UI can surface the lock + a "try again at…" message.
    static func extract(from input: String) async throws -> [DraftTask] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        do {
            let json = try await OpenAIClient().extractTasks(from: trimmed)
            if let data = json.data(using: .utf8),
               let parsed = try? JSONDecoder().decode(TaskExtractionResponse.self, from: data) {
                return parsed.tasks.map {
                    DraftTask(
                        id: UUID(),
                        title: $0.title,
                        category: $0.category,
                        suggestedEnergyRaw: $0.suggestedEnergy.lowercased()
                    )
                }
            }
        } catch OpenAIClientError.quotaExceeded(let resetsAt) {
            throw OpenAIClientError.quotaExceeded(resetsAt: resetsAt)
        } catch {
            // Non-quota AI failure — fall through to rule-based.
        }

        return ruleBasedFallback(from: trimmed)
    }

    /// Internal so onboarding can silently degrade to local extraction on
    /// any failure (including quota), without surfacing the lock UI during a
    /// user's first run.
    static func ruleBasedFallback(from input: String) -> [DraftTask] {
        let separators: CharacterSet = CharacterSet(charactersIn: ",\n;")
        let pieces = input.components(separatedBy: separators)
            .flatMap { $0.components(separatedBy: " and ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 80 }

        return pieces.map {
            DraftTask(
                id: UUID(),
                title: $0,
                category: "Personal",
                suggestedEnergyRaw: EnergyLevel.steady.rawValue
            )
        }
    }
}
