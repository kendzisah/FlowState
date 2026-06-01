import WidgetKit
import SwiftUI
import AppIntents

/// 2x2 Home Screen — the differentiator. Shows the current energy state +
/// the single best task to start right now. Foggy energy renders rest-mode
/// messaging instead of a task list. Without an energy check-in for the day,
/// shows the four energy dots so the user can declare from the widget.
struct SmallRecommendationWidget: Widget {
    let kind = "FlowState.SmallRecommendation"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SharedTimelineProvider()) { entry in
            SmallRecommendationView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Recommendation")
        .description("Your current energy + the best task to start right now.")
        .supportedFamilies([.systemSmall])
    }
}

private struct SmallRecommendationView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if let session = snapshot.activeSession {
            inSessionView(session)
        } else if let energy = snapshot.energy, let level = EnergyLevelLite(rawValue: energy.level) {
            switch level {
            case .foggy:
                foggyRestView(energy: energy, level: level)
            default:
                if let task = snapshot.recommendation {
                    recommendationView(energy: energy, level: level, task: task)
                } else {
                    noMatchView(energy: energy, level: level)
                }
            }
        } else {
            checkinPromptView
        }
    }

    // MARK: - In-session

    private func inSessionView(_ session: SnapshotActiveSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(Color(hex: session.energyHex)).frame(width: 9, height: 9)
                Text("In session")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(session.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(2)
            Spacer(minLength: 0)
            timerLabel(for: session)
                .font(.system(size: 22, weight: .light, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "flowstate://timer"))
    }

    @ViewBuilder
    private func timerLabel(for session: SnapshotActiveSession) -> some View {
        if let endsAt = session.endsAt, session.mode == "countdown" {
            Text(timerInterval: Date()...endsAt, countsDown: true)
        } else {
            Text(timerInterval: session.startedAt...Date.distantFuture, countsDown: false)
        }
    }

    // MARK: - Foggy

    private func foggyRestView(energy: SnapshotEnergy, level: EnergyLevelLite) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(level.color).frame(width: 9, height: 9)
                Text(level.shortLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text("Your brain needs a break.")
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(3)
            Text("Recovery counts.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "flowstate://timer"))
    }

    // MARK: - Recommendation

    private func recommendationView(
        energy: SnapshotEnergy,
        level: EnergyLevelLite,
        task: SnapshotTaskRow
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(level.color).frame(width: 9, height: 9)
                Text(level.shortLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 2)
            Text(task.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(2)
            if let seconds = task.durationEstimateSeconds {
                Text("~\(seconds / 60) min")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(intent: StartTaskIntent(taskID: task.id)) {
                Text("Start")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(level.color)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - No matching tasks

    private func noMatchView(energy: SnapshotEnergy, level: EnergyLevelLite) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(level.color).frame(width: 9, height: 9)
                Text(level.shortLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text("No matching tasks.")
                .font(.system(size: 14, weight: .semibold))
            Text("Add one to get started.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "flowstate://add"))
    }

    // MARK: - Energy check-in row

    private var checkinPromptView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How's your brain?")
                .font(.system(size: 13, weight: .semibold))
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                ForEach(EnergyLevelLite.allCases.filter { $0 != .foggy }, id: \.self) { level in
                    Button(intent: SetEnergyIntent(level: level.rawValue)) {
                        VStack(spacing: 4) {
                            Circle().fill(level.color).frame(width: 16, height: 16)
                            Text(level.shortLabel)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
            Button(intent: SetEnergyIntent(level: EnergyLevelLite.foggy.rawValue)) {
                HStack(spacing: 4) {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 10))
                    Text("Foggy")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
