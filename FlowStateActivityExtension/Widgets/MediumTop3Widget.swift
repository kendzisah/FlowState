import WidgetKit
import SwiftUI
import AppIntents

/// 4x2 Home Screen — replaces "open app and look at list" with a glance.
/// Shows current energy header + up to 3 sorted tasks with duration estimates.
/// Foggy energy shows rest-mode messaging instead of tasks. In-session,
/// shows the active task with a dimmed list below.
struct MediumTop3Widget: Widget {
    let kind = "FlowState.MediumTop3"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SharedTimelineProvider()) { entry in
            MediumTop3View(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Top 3 Tasks")
        .description("The three best tasks to do right now, sorted by your current energy.")
        .supportedFamilies([.systemMedium])
    }
}

private struct MediumTop3View: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if let session = snapshot.activeSession {
            inSessionView(session)
        } else if let energy = snapshot.energy, let level = EnergyLevelLite(rawValue: energy.level) {
            switch level {
            case .foggy: foggyRestView(level: level)
            default:     listView(level: level)
            }
        } else {
            checkinPromptView
        }
    }

    // MARK: - Active

    private func inSessionView(_ session: SnapshotActiveSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(Color(hex: session.energyHex)).frame(width: 9, height: 9)
                Text("Currently focused on \(session.title)")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                timerLabel(session)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
            }

            ForEach(snapshot.topTasks, id: \.id) { row in
                taskRow(row, dimmed: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "flowstate://timer"))
    }

    @ViewBuilder
    private func timerLabel(_ session: SnapshotActiveSession) -> some View {
        if let endsAt = session.endsAt, session.mode == "countdown" {
            Text(timerInterval: Date()...endsAt, countsDown: true)
        } else {
            Text(timerInterval: session.startedAt...Date.distantFuture, countsDown: false)
        }
    }

    // MARK: - Foggy

    private func foggyRestView(level: EnergyLevelLite) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(level.color).frame(width: 9, height: 9)
                Text(level.shortLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text("Today is a rest day.")
                .font(.system(size: 17, weight: .semibold))
            Text("Recovery counts.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "flowstate://timer"))
    }

    // MARK: - List

    private func listView(level: EnergyLevelLite) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(level.color).frame(width: 9, height: 9)
                Text("\(level.shortLabel) · \(snapshot.topTasks.count) \(snapshot.topTasks.count == 1 ? "task" : "tasks") ready")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .widgetURL(URL(string: "flowstate://timer"))

            if snapshot.topTasks.isEmpty {
                Spacer(minLength: 0)
                Text("Add your first task")
                    .font(.system(size: 14, weight: .semibold))
                Link(destination: URL(string: "flowstate://add")!) {
                    Text("+ Add task")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(level.color)
                }
                Spacer(minLength: 0)
            } else {
                ForEach(snapshot.topTasks, id: \.id) { row in
                    taskRow(row, dimmed: false)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func taskRow(_ row: SnapshotTaskRow, dimmed: Bool) -> some View {
        let level = EnergyLevelLite(rawValue: row.energyTag) ?? .steady
        Button(intent: StartTaskIntent(taskID: row.id)) {
            HStack(spacing: 8) {
                Image(systemName: level.iconName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(level.color)
                    .frame(width: 16)
                Text(row.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer()
                if let seconds = row.durationEstimateSeconds {
                    Text("~\(seconds / 60) min")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(dimmed ? 0.5 : 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Check-in prompt

    private var checkinPromptView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How's your energy?")
                .font(.system(size: 15, weight: .semibold))
            HStack(spacing: 8) {
                ForEach(EnergyLevelLite.allCases.filter { $0 != .foggy }, id: \.self) { level in
                    Button(intent: SetEnergyIntent(level: level.rawValue)) {
                        VStack(spacing: 4) {
                            Circle().fill(level.color).frame(width: 18, height: 18)
                            Text(level.shortLabel)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button(intent: SetEnergyIntent(level: EnergyLevelLite.foggy.rawValue)) {
                HStack(spacing: 4) {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 11))
                    Text("Foggy — I need rest")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
