import Foundation
import SwiftData

/// Bulk action for the Anytime bucket on the Calendar tab. For each item the
/// user dumped into Anytime, decides:
///   • A time-of-day slot (morning / afternoon / evening) — never `.anytime`,
///     so the bucket is actually emptied.
///   • An energy tag — only applied to events whose energy the user hasn't
///     manually set. Tasks keep their existing energy.
///
/// Heuristic-first: every item gets a deterministic decision before the AI
/// call runs. Successful AI responses override the heuristic per-index. So
/// AI failures (network down, decoding mismatch, missing key) never leave
/// items stuck in Anytime.
@MainActor
enum AnytimeAutoSorter {
    struct Decision: Equatable {
        let energy: EnergyLevel?
        let slot: DayTimeSlot   // .anytime is replaced with .morning before apply
    }

    static func sort(items: [DayItem], on day: Date, in context: ModelContext) async {
        guard !items.isEmpty else { return }

        // 1. Heuristic baseline so the AI is purely a refinement.
        var decisions: [Int: Decision] = [:]
        for (i, item) in items.enumerated() {
            decisions[i] = Decision(
                energy: heuristicEnergy(for: item),
                slot: heuristicSlot(for: item.title)
            )
        }

        // 2. AI override per item (best effort).
        if let aiResult = await tryOpenAI(items: items) {
            for (i, decision) in aiResult {
                decisions[i] = decision
            }
        }

        // 3. Apply.
        let calendar = Calendar.current
        for (i, item) in items.enumerated() {
            guard let decision = decisions[i] else { continue }
            let resolvedSlot: DayTimeSlot = decision.slot == .anytime ? .morning : decision.slot

            switch item {
            case .event(let event):
                if !event.userOverrideEnergy, let level = decision.energy {
                    event.energyRaw = level.rawValue
                }
                event.displaySlot = resolvedSlot
            case .task(let task, _):
                task.scheduledDate = slotDate(for: resolvedSlot, on: day, calendar: calendar)
            }
        }
        context.saveAndSync()
    }

    // MARK: - Heuristics

    private static func heuristicEnergy(for item: DayItem) -> EnergyLevel? {
        switch item {
        case .event(let e):
            if e.userOverrideEnergy { return e.energy }
            return EventEnergyClassifier.heuristic(for: e.title)
        case .task(let t, _):
            return t.energyTag
        }
    }

    private static func heuristicSlot(for title: String) -> DayTimeSlot {
        let t = title.lowercased()
        let morningHints   = ["morning", "breakfast", "standup", "stand-up", "coffee", "wake"]
        let afternoonHints = ["lunch", "afternoon", "midday", "noon"]
        let eveningHints   = ["dinner", "evening", "night", "supper", "drinks", "bedtime"]

        if eveningHints.contains(where: t.contains)   { return .evening }
        if afternoonHints.contains(where: t.contains) { return .afternoon }
        if morningHints.contains(where: t.contains)   { return .morning }
        return .morning   // default — get it on the list early
    }

    private static func slotDate(for slot: DayTimeSlot, on day: Date, calendar: Calendar) -> Date {
        let dayStart = calendar.startOfDay(for: day)
        let hour: Int
        switch slot {
        case .anytime:   hour = 0
        case .morning:   hour = 9
        case .afternoon: hour = 14
        case .evening:   hour = 19
        }
        return calendar.date(byAdding: .hour, value: hour, to: dayStart) ?? dayStart
    }

    // MARK: - OpenAI

    private static let systemPrompt = """
    You organize calendar items for an ADHD focus app. For each item, pick the
    best time of day to tackle it and the focus energy it requires. Use the
    title and any context it implies. Return ONLY a JSON object — no markdown,
    no prose.
    """

    private static func tryOpenAI(items: [DayItem]) async -> [Int: Decision]? {
        let payload = items.enumerated().map { i, item in
            let title = item.title.replacingOccurrences(of: "\"", with: "\\\"")
            return "\(i). \"\(title)\""
        }.joined(separator: "\n")

        let userPrompt = """
        For each item below, choose:
          • slot: "morning" | "afternoon" | "evening" (never "anytime")
          • energy: "scattered" | "steady" | "locked"

        Energy guide:
          - scattered: low focus (admin, standups, emails, errands, 1:1s)
          - steady:    medium focus (planning, light work, design review)
          - locked:    high focus (deep work, study, writing, complex coding)

        Slot guide:
          - morning: high-focus work, fresh-brain tasks, planning the day
          - afternoon: meetings, collaboration, social
          - evening: low-cost wind-down, errands, casual social

        Return ONLY:
        {"items":[{"i":<index>,"slot":"...","energy":"..."}, ...]}

        Use the integer "i" exactly as listed. One entry per item.

        Items:
        \(payload)
        """

        do {
            let json = try await OpenAIClient().chatJSON(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            )
            struct Item: Decodable {
                let i: Int
                let slot: String
                let energy: String?
            }
            struct Envelope: Decodable { let items: [Item] }
            guard let data = json.data(using: .utf8),
                  let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else {
                return nil
            }
            var out: [Int: Decision] = [:]
            for item in envelope.items {
                let slot = DayTimeSlot(rawValue: item.slot.lowercased()) ?? .morning
                let resolvedSlot = (slot == .anytime) ? .morning : slot
                let energy: EnergyLevel? = {
                    guard let raw = item.energy,
                          let level = EnergyLevel(rawValue: raw.lowercased()),
                          EnergyLevel.taskAssignable.contains(level) else { return nil }
                    return level
                }()
                out[item.i] = Decision(energy: energy, slot: resolvedSlot)
            }
            return out.isEmpty ? nil : out
        } catch {
            return nil
        }
    }
}
