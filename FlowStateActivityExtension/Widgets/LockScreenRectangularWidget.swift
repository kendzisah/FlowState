import WidgetKit
import SwiftUI

/// Lock Screen Rectangular widget. Highest-visibility surface — passive
/// reinforcement of active session without unlocking the phone. Five states:
///   • Active session — countdown or count-up timer + task title
///   • No active session, energy declared — energy + matching task count
///   • No active session, no check-in — "Energy check-in pending"
///   • Parked task exists (priority over no-checkin) — "N tasks parked"
struct LockScreenRectangularWidget: Widget {
    let kind = "FlowState.LockScreenRectangular"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SharedTimelineProvider()) { entry in
            LockScreenRectangularView(snapshot: entry.snapshot)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("FlowState — Lock Screen")
        .description("Glance-clear status of your current focus session or energy state.")
        .supportedFamilies([.accessoryRectangular])
    }
}

private struct LockScreenRectangularView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if let session = snapshot.activeSession {
            sessionView(session)
        } else if snapshot.parked.count > 0 {
            parkedView(snapshot.parked)
        } else if let energy = snapshot.energy, let level = EnergyLevelLite(rawValue: energy.level) {
            idleWithEnergyView(level: level, taskCount: snapshot.topTasks.count)
        } else {
            checkinPendingView
        }
    }

    private func sessionView(_ session: SnapshotActiveSession) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(.secondary).frame(width: 6, height: 6)
                timerLabel(session)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
            }
            Text(session.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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

    private func parkedView(_ parked: SnapshotParked) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("\(parked.count) parked")
                    .font(.system(size: 13, weight: .semibold))
            }
            if let row = parked.mostRecent {
                Text("Resume \(row.title)")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "flowstate://parked"))
    }

    private func idleWithEnergyView(level: EnergyLevelLite, taskCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: level.iconName)
                    .font(.system(size: 10, weight: .semibold))
                Text("\(level.shortLabel) today")
                    .font(.system(size: 13, weight: .semibold))
            }
            Text("\(taskCount) \(taskCount == 1 ? "task" : "tasks") ready")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "flowstate://timer"))
    }

    private var checkinPendingView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Energy check-in pending")
                .font(.system(size: 13, weight: .semibold))
            Text("Tap to open")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "flowstate://checkin"))
    }
}
