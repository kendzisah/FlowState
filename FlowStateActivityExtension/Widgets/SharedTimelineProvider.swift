import WidgetKit

/// Single TimelineProvider used by all four home-screen widgets. Reads the
/// current `WidgetSnapshot` from App Group UserDefaults each refresh and
/// returns a one-entry timeline with a ~30 min refresh policy.
///
/// Why one provider for all surfaces: every widget renders off the same
/// snapshot, so duplicating per-widget providers would just multiply the
/// same UserDefaults read.
struct SnapshotTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SharedTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotTimelineEntry {
        SnapshotTimelineEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotTimelineEntry) -> Void) {
        let entry = SnapshotTimelineEntry(date: Date(), snapshot: WidgetSnapshotStore.read())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotTimelineEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetSnapshotStore.read()
        let entry = SnapshotTimelineEntry(date: now, snapshot: snapshot)

        // 30-min cadence is a sensible default — most state changes already
        // trigger an immediate reload via `WidgetCenter.reloadAllTimelines()`
        // from the main app. The cadence covers the case where the app
        // hasn't run all day (e.g., the user backed out before checking in).
        let nextReload = now.addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextReload)))
    }
}
