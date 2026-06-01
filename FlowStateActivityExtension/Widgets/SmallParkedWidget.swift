import WidgetKit
import SwiftUI
import AppIntents

/// 2x2 Home Screen — dedicated surface for the Parked Queue so parked tasks
/// don't die in a graveyard. Shows count + most-recent parked task with a
/// Resume button. Empty state subtly educates about Park This.
struct SmallParkedWidget: Widget {
    let kind = "FlowState.SmallParked"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SharedTimelineProvider()) { entry in
            SmallParkedView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Parked Queue")
        .description("Tasks you've paused — pick up where you left off.")
        .supportedFamilies([.systemSmall])
    }
}

private struct SmallParkedView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if let row = snapshot.parked.mostRecent {
            populatedView(row: row, count: snapshot.parked.count)
        } else {
            emptyView
        }
    }

    private func populatedView(row: SnapshotParkedRow, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Parked Queue")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text("\(count) \(count == 1 ? "task" : "tasks") waiting")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text(row.title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(2)
            Text("Park: \(relativeLabel(for: row.parkedAt))")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Button(intent: ResumeTaskIntent(parkedID: row.id)) {
                Text("Resume")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "C9A876")) // parkedAccent in app palette
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "pause.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Parked Queue")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text("Nothing parked.")
                .font(.system(size: 14, weight: .semibold))
            Text("Park This saves a session for later — no momentum lost.")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "flowstate://parked/learn"))
    }

    private func relativeLabel(for date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }
}
