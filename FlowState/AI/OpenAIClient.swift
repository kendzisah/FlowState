import Foundation
import RevenueCat

enum OpenAIClientError: Error {
    case missingProxyConfig         // SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY not wired
    case missingUserIdentity        // RevenueCat appUserID unavailable
    case notAuthenticated           // No Supabase session JWT to send to the proxy
    case http(Int, String)
    case decoding
    case network(Error)
    case quotaExceeded(resetsAt: Date)
    /// Input exceeded `OpenAIClient.maxUserPromptCharacters`. Client-side
    /// pre-flight check — prevents the Edge Function from spending tokens
    /// on a request we'd reject server-side anyway.
    case inputTooLong(limit: Int, given: Int)
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

    /// Hard cap on user-supplied text per request. Keeps OpenAI token cost
    /// bounded and blocks abusive paste-walls before they hit the proxy.
    /// Surfaced as a public constant so the chat input UI can show the same
    /// limit (counter + over-limit warning).
    static let maxUserPromptCharacters = 2000

    /// Hard cap on the assistant's response. 500 tokens is generous for a
    /// task list (~50–100 tasks) but tight enough that an attempt to coax
    /// prose out of the model gets truncated mid-stream → the client's
    /// strict JSON decoder rejects it → the user sees the "couldn't pull
    /// tasks" message. The Edge Function must forward this to OpenAI's
    /// `max_tokens` parameter.
    private let maxResponseTokens = 500

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
        // Client-side length check — fail fast before consuming quota.
        let count = userPrompt.count
        if count > Self.maxUserPromptCharacters {
            throw OpenAIClientError.inputTooLong(
                limit: Self.maxUserPromptCharacters,
                given: count
            )
        }

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

        // The Edge Function is published with `verify_jwt: true`, so the
        // Supabase gateway rejects (401) any request whose Authorization
        // header isn't a real JWT — the new-format `sb_publishable_*` key
        // does NOT validate as one. Use the user's session access token
        // (refreshed if needed), and put the publishable key in `apikey`
        // — same dual-header shape SyncEngine uses for PostgREST calls.
        let accessToken: String
        do {
            accessToken = try await AuthManager.shared.accessTokenForRequest()
        } catch {
            throw OpenAIClientError.notAuthenticated
        }

        let body: [String: Any] = [
            "systemPrompt": systemPrompt,
            "userPrompt": userPrompt,
            "temperature": temperature,
            "model": model,
            "responseFormat": "json_object",
            // Edge Function should forward to OpenAI's `max_tokens` so prose
            // attempts get truncated mid-output (and the strict client
            // decoder then rejects them).
            "maxTokens": maxResponseTokens,
        ]

        var request = URLRequest(url: proxyEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(userID, forHTTPHeaderField: "X-User-ID")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = timeoutSeconds

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            AnalyticsErrorReporter.report(error, context: "ai.openai.request")
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
        You are FlowState, a calm planning assistant for ADHD users. Your ONLY job is to \
        turn the user's messy input into a clean list of action-oriented tasks. You are \
        NOT a chatbot, search engine, advisor, writer, or coder.

        Refusal rules — follow exactly:
        • If the input is a question, a request for information, prose, code, a greeting, \
        an opinion request, or anything that isn't a list of tasks the user wants to do, \
        return exactly {"tasks": []}. Do not invent tasks. Do not answer.
        • Never include answers, advice, opinions, summaries, jokes, weather, definitions, \
        or any content the user did not explicitly write as a to-do item in task titles.
        • Task titles must be things the USER will do — not things YOU will do, not \
        descriptions, not commentary.

        When the input IS a task list: REWRITE each item into a short, action-oriented \
        task title. DO NOT copy the user's sentence verbatim. Transform it.

        Title rules:
        • Start each title with an imperative verb: Buy, Send, Call, Write, Review, Book, \
        Pick up, Schedule, Pay, Submit, Clean, Reply to, Plan, Fix, Finish, Read, etc.
        • Drop filler words: "I need to", "I have to", "remember to", "I should", "gotta", \
        "I want to", "make sure to". These are noise — the title is the action itself.
        • Drop time/date qualifiers like "tonight", "tomorrow", "this morning", "later", \
        "at 3pm" — the title is the action, not when it happens.
        • Keep titles 3–8 words. Concrete enough to act on, short enough to scan.
        • Split compound items into separate tasks ("do laundry and dishes" → two tasks). \
        Keep enumerations as one task when they share an action ("buy milk, bread, eggs" \
        → one "Buy groceries" task).
        • Use sentence case (first word capitalized, rest lowercase unless proper noun).

        Examples:
        Input: "I need to get milk and bread from the store tonight"
        Output: {"tasks": [{"title": "Buy milk and bread", ...}]}

        Input: "Gotta send John that email about the Q1 review and also book a haircut"
        Output: {"tasks": [{"title": "Email John about Q1 review", ...}, {"title": "Book haircut appointment", ...}]}

        Input: "remember to pick up the kids at 3pm and pay the electric bill"
        Output: {"tasks": [{"title": "Pick up kids", ...}, {"title": "Pay electric bill", ...}]}

        Input: "laundry and dishes and vacuum the living room"
        Output: {"tasks": [{"title": "Do the laundry", ...}, {"title": "Wash the dishes", ...}, {"title": "Vacuum living room", ...}]}

        For each task, suggest an energy tag: "scattered" (low focus, e.g. emails, errands), \
        "steady" (medium focus, e.g. planning, light work), or "locked" (high focus, e.g. \
        deep work, learning). Never use "foggy" — that's a rest state, not a task tag. \
        Categorize each task: "Work", "Personal", "Errand", "Social", or "Home".

        Return ONLY a JSON object: \
        {"tasks": [{"title": "...", "category": "...", "suggestedEnergy": "..."}]}
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
            Analytics.track(.chatQuotaExceeded(resetsAt: ISO8601DateFormatter().string(from: resetsAt)))
            AnalyticsErrorReporter.reportMessage("AI quota exceeded", context: "ai.openai.quota", level: "warning")
            throw OpenAIClientError.quotaExceeded(resetsAt: resetsAt)
        } catch {
            // Non-quota AI failure — fall through to rule-based.
            AnalyticsErrorReporter.report(error, context: "ai.openai.other")
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
