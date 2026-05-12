import Foundation
import SwiftData

@MainActor
enum EventEnergyClassifier {
    /// Classifies the energy of every event without a user-override. The AI path
    /// is best-effort; any event the model fails to classify is filled in by the
    /// regex heuristic so the UI is never left with an unclassified card.
    static func classify(events: [ImportedEvent], in context: ModelContext) async {
        let pending = events.filter { !$0.userOverrideEnergy }
        guard !pending.isEmpty else { return }

        // Start with the heuristic so every event has a baseline. AI overrides
        // when it returns a valid result; otherwise we keep the heuristic value.
        var mapping: [Int: EnergyLevel] = [:]
        for (i, event) in pending.enumerated() {
            mapping[i] = heuristic(for: event.title)
        }

        if let aiResult = await tryOpenAI(events: pending) {
            for (i, level) in aiResult {
                mapping[i] = level
            }
        }

        for (i, event) in pending.enumerated() {
            if let level = mapping[i] {
                event.energyRaw = level.rawValue
            }
        }
        context.saveAndSync()
    }

    // MARK: - OpenAI

    /// Sends events to the model keyed by 0-based index. Indices round-trip
    /// cleanly through JSON, unlike EventKit's long opaque identifiers which
    /// the model often abbreviates or sanitizes.
    private static func tryOpenAI(events: [ImportedEvent]) async -> [Int: EnergyLevel]? {
        let chunkSize = 20
        let chunks = stride(from: 0, to: events.count, by: chunkSize).map { offset -> (Int, [ImportedEvent]) in
            let slice = Array(events[offset..<min(offset + chunkSize, events.count)])
            return (offset, slice)
        }

        var aggregate: [Int: EnergyLevel] = [:]
        var anyChunkSucceeded = false
        for (baseIndex, chunk) in chunks {
            guard let chunkResult = await classifyChunk(chunk) else { continue }
            anyChunkSucceeded = true
            for (localIndex, level) in chunkResult {
                aggregate[baseIndex + localIndex] = level
            }
        }
        return anyChunkSucceeded ? aggregate : nil
    }

    private static let energySystemPrompt = """
    You classify calendar events for an ADHD focus app. Read each event and
    decide what kind of mental energy it requires. Return ONLY a JSON object —
    no markdown, no prose, no commentary.
    """

    private static func classifyChunk(_ events: [ImportedEvent]) async -> [Int: EnergyLevel]? {
        let payload = events.enumerated().map { idx, event in
            let duration = max(0, Int(event.endDate.timeIntervalSince(event.startDate) / 60))
            let title = event.title.replacingOccurrences(of: "\"", with: "\\\"")
            return "\(idx). \"\(title)\" (\(duration) min)"
        }.joined(separator: "\n")

        let userPrompt = """
        Classify each event below by the focus energy it requires. Return ONLY:
        {"items":[{"i":<index>,"energy":"scattered"|"steady"|"locked"}, ...]}

        - "scattered": low focus (admin, standups, emails, errands, 1:1s)
        - "steady": medium focus (planning, light work, design review)
        - "locked": high focus (deep work, study, writing, complex coding)

        Use the integer "i" exactly as listed. One entry per event.

        Events:
        \(payload)
        """

        do {
            let json = try await OpenAIClient().chatJSON(
                systemPrompt: energySystemPrompt,
                userPrompt: userPrompt
            )
            struct Item: Decodable {
                let i: Int
                let energy: String
            }
            struct Envelope: Decodable { let items: [Item] }
            guard let data = json.data(using: .utf8),
                  let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else {
                return nil
            }
            var out: [Int: EnergyLevel] = [:]
            for item in envelope.items {
                if let level = EnergyLevel(rawValue: item.energy.lowercased()),
                   EnergyLevel.taskAssignable.contains(level) {
                    out[item.i] = level
                }
            }
            return out.isEmpty ? nil : out
        } catch {
            return nil
        }
    }

    // MARK: - Rule-based fallback

    nonisolated static func ruleBasedFallback(events: [ImportedEvent]) -> [String: EnergyLevel] {
        var result: [String: EnergyLevel] = [:]
        for event in events {
            result[event.externalIdentifier] = heuristic(for: event.title)
        }
        return result
    }

    nonisolated static func heuristic(for title: String) -> EnergyLevel {
        let t = title.lowercased()
        let scatteredHints = ["standup", "stand-up", "email", "errand", "admin", "sync", "1:1", "1-on-1", "check-in", "checkin"]
        let lockedHints = ["deep work", "focus", "study", "writing", "design", "build", "code", "coding", "research"]

        if scatteredHints.contains(where: t.contains) { return .scattered }
        if lockedHints.contains(where: t.contains)    { return .locked }
        return .steady
    }
}
