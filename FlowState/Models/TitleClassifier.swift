import Foundation

enum TitleClassifier {
    static let scatteredVerbs: Set<String> = [
        "reply", "tidy", "clear", "sort", "file", "email", "text", "send",
        "schedule", "skim", "delete", "archive", "ping", "rsvp"
    ]
    static let steadyVerbs: Set<String> = [
        "draft", "write", "read", "review", "outline", "edit", "summarize",
        "research", "note", "study", "fix", "plan"
    ]
    static let lockedVerbs: Set<String> = [
        "refactor", "design", "architect", "build", "implement", "model",
        "rewrite", "spec", "compose", "deep", "prototype"
    ]

    struct Suggestion: Equatable {
        let level: EnergyLevel
        let confidence: Double
    }

    /// Returns a suggestion only if confidence ≥ 0.6.
    static func classify(_ title: String) -> Suggestion? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }

        let words = trimmed
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return nil }

        var scores: [EnergyLevel: Double] = [
            .scattered: 0,
            .steady: 0,
            .locked: 0
        ]

        for w in words {
            if scatteredVerbs.contains(w) { scores[.scattered, default: 0] += 0.6 }
            if steadyVerbs.contains(w)    { scores[.steady,    default: 0] += 0.6 }
            if lockedVerbs.contains(w)    { scores[.locked,    default: 0] += 0.6 }
        }

        if words.count <= 3 {
            scores[.scattered, default: 0] += 0.2
        } else if words.count >= 6 {
            scores[.locked, default: 0] += 0.2
        } else {
            scores[.steady, default: 0] += 0.2
        }

        guard let best = scores.max(by: { $0.value < $1.value }) else { return nil }
        guard best.value >= 0.6 else { return nil }
        return Suggestion(level: best.key, confidence: min(best.value, 1.0))
    }
}
