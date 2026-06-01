// MUST stay byte-identical with FlowState/Widgets/AppIntents/SetEnergyIntent.swift
import AppIntents

/// Tapped from the Small Recommendation widget's energy-dot row when the
/// user hasn't checked in yet today. Records the chosen energy and opens
/// the app to the recommendations view.
struct SetEnergyIntent: AppIntent {
    static let title: LocalizedStringResource = "Set energy"
    static let description: IntentDescription = IntentDescription("Record how your brain feels and surface matching tasks.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Energy level")
    var level: String   // EnergyLevel rawValue: foggy / scattered / steady / locked

    init() {}
    init(level: String) { self.level = level }

    func perform() async throws -> some IntentResult {
        PendingWidgetActionQueue.enqueue(.setEnergy(level: level))
        return .result()
    }
}
