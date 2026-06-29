import Foundation
import SwiftData
import UIKit

/// "Routine group run": the Calendar Start button walks the user through a
/// group's tasks one at a time under a single shared countdown (the group's
/// `runDurationSeconds`). It reuses the regular timer plumbing — `activeTask`,
/// the ticker, Live Activity, widgets — but with three behavioural twists,
/// gated on `activeRoutineRun != nil`:
///
///   1. Completing the active task advances to the next in the queue and keeps
///      the **same** countdown running (it doesn't reset per task) instead of
///      ending the session.
///   2. The countdown hitting 0 doesn't end the run (see `tick()` guard) — the
///      duration is a soft guide; the run ends when every task is done.
///   3. Pausing stashes the run on the Calendar (a Resume button) rather than
///      creating a `ParkedTask` on the Tasks tab.
extension AppStore {
    /// True while `group` is the run currently on the timer.
    func isRunning(group: RoutineGroup) -> Bool {
        activeRoutineRun?.groupID == group.id
    }

    /// True when `group` has a paused run waiting to be resumed from the Calendar.
    func isPaused(group: RoutineGroup) -> Bool {
        pausedRoutineRuns[group.id] != nil
    }

    /// Begin (or restart) a run for `group`. `tasks` is today's tasks for the
    /// group, in display order; only the still-incomplete ones are queued.
    func startRoutineRun(group: RoutineGroup, tasks: [Task], context: ModelContext?) {
        // Don't clobber an in-flight session (single-task timer or another run).
        guard activeTask == nil, activeRoutineRun == nil else { return }
        let queue = tasks.filter { !$0.isCompleted }
        guard let first = queue.first else { return }

        let total = group.runDurationSeconds
        let run = RoutineRunState(
            groupID: group.id,
            groupTitle: group.title,
            groupEmoji: group.emoji,
            remainingTaskIDs: queue.map(\.id),
            completedCount: tasks.count - queue.count,
            totalCount: tasks.count,
            totalDurationSeconds: total,
            stashedSecondsRemaining: total
        )
        pausedRoutineRuns[group.id] = nil
        beginRun(run, with: first, secondsRemaining: total)
    }

    /// Resume a paused run for `group`. `tasks` is re-read from today's list so
    /// any tasks completed elsewhere drop out of the queue.
    func resumeRoutineRun(group: RoutineGroup, tasks: [Task], context: ModelContext?) {
        guard activeTask == nil, activeRoutineRun == nil else { return }
        guard let paused = pausedRoutineRuns[group.id] else {
            startRoutineRun(group: group, tasks: tasks, context: context)
            return
        }
        let queue = tasks.filter { !$0.isCompleted }
        guard let first = queue.first else {
            // Nothing left to run — the group was finished elsewhere.
            pausedRoutineRuns[group.id] = nil
            return
        }

        var run = paused
        run.remainingTaskIDs = queue.map(\.id)
        run.completedCount = run.totalCount - queue.count
        pausedRoutineRuns[group.id] = nil
        beginRun(run, with: first, secondsRemaining: max(paused.stashedSecondsRemaining, 0))
    }

    /// Shared "put a run on the timer" path for start + resume.
    private func beginRun(_ run: RoutineRunState, with task: Task, secondsRemaining: Int) {
        showDurationPicker = false
        showEnergySwitcher = false
        showAddTask = false

        activeRoutineRun = run
        activeTask = task
        timerMode = .countdown
        timerDurationSeconds = run.totalDurationSeconds
        timerSecondsRemaining = secondsRemaining
        timerElapsedSeconds = max(run.totalDurationSeconds - secondsRemaining, 0)
        timerRunning = true

        // Land the user back on the Calendar when the run ends/pauses, where the
        // group (and its Resume button) live.
        homeTab = .calendar

        impactHaptic(.medium)
        startTicker()

        // Routine runs intentionally skip the "Session complete" timer
        // notification — the run isn't clock-bound.
        NotificationManager.cancelCompletion()
        if notificationsEnabled {
            _Concurrency.Task { await NotificationManager.requestAuthorizationIfNeeded() }
        }

        // Live Activity shows the *group* (stable across task transitions).
        let energy = energyLevel ?? .steady
        LiveActivityController.start(
            taskID: run.groupID.uuidString,
            taskTitle: runActivityTitle(for: run),
            energyHex: energy.hexString,
            mode: .countdown,
            secondsRemaining: timerSecondsRemaining,
            secondsElapsed: timerElapsedSeconds,
            totalDuration: timerDurationSeconds
        )
        WidgetSnapshotWriter.refresh(store: self, context: nil)
    }

    /// Mark the current routine task done and advance — or, if it was the last,
    /// finish the run with a celebration. Called from the timer's Done button.
    func completeRoutineTask(_ task: Task, context: ModelContext?) {
        guard var run = activeRoutineRun else {
            // Defensive: not actually in a run — fall back to normal completion.
            completeTask(task, context: context)
            return
        }

        Analytics.track(.taskCompleted(
            taskID: task.id.uuidString,
            durationSeconds: currentElapsed(),
            energyLevel: nil,
            via: "routine_run"
        ))

        task.isCompleted = true
        task.completedAt = Date()
        task.markDirty()
        context?.saveAndSync()

        run.remainingTaskIDs.removeAll { $0 == task.id }
        run.completedCount += 1

        // More tasks to go → advance, keep the same countdown running.
        if let nextID = run.remainingTaskIDs.first,
           let next = fetchTask(id: nextID, context: context) {
            activeRoutineRun = run
            activeTask = next
            impactHaptic(.light)          // small per-task acknowledgement
            LiveActivityController.update(
                mode: timerMode,
                secondsRemaining: timerSecondsRemaining,
                secondsElapsed: timerElapsedSeconds
            )
            WidgetSnapshotWriter.refresh(store: self, context: context)
            return
        }

        // Last task done → finish the run.
        finishRoutineRun(run, context: context)
    }

    /// Pause the active run: stash it for the Calendar's Resume button. Does NOT
    /// create a ParkedTask (the user asked for routine resume on the Calendar,
    /// not the Tasks tab). Called from the timer's Pause button.
    func pauseRoutineRun(context: ModelContext?) {
        guard var run = activeRoutineRun else { return }
        run.stashedSecondsRemaining = timerSecondsRemaining
        pausedRoutineRuns[run.groupID] = run

        Analytics.track(.taskParked(
            taskID: run.groupID.uuidString,
            elapsedSeconds: currentElapsed()
        ))

        activeRoutineRun = nil
        activeTask = nil
        timerRunning = false
        stopTicker()

        NotificationManager.cancelCompletion()
        LiveActivityController.end()
        impactHaptic(.light)
        homeTab = .calendar
        WidgetSnapshotWriter.refresh(store: self, context: context)
    }

    private func finishRoutineRun(_ run: RoutineRunState, context: ModelContext?) {
        activeRoutineRun = nil
        activeTask = nil
        timerRunning = false
        stopTicker()

        NotificationManager.cancelCompletion()
        LiveActivityController.setComplete()

        // The celebration: reuse the completion dialog (the app's single
        // sanctioned celebratory moment) plus a success haptic.
        successHaptic()
        let emoji = (run.groupEmoji?.isEmpty == false) ? "\(run.groupEmoji!) " : ""
        let done = run.totalCount
        completionDialog = CompletionDialogState(
            taskTitle: "\(emoji)\(run.groupTitle)",
            affirmation: done == 1
                ? "Routine complete. Nice."
                : "Routine complete — all \(done) done."
        )
        homeTab = .calendar
        WidgetSnapshotWriter.refresh(store: self, context: context)
    }

    // MARK: - Helpers

    private func runActivityTitle(for run: RoutineRunState) -> String {
        let emoji = (run.groupEmoji?.isEmpty == false) ? "\(run.groupEmoji!) " : ""
        return "\(emoji)\(run.groupTitle)"
    }

    private func fetchTask(id: UUID, context: ModelContext?) -> Task? {
        guard let context else { return nil }
        var descriptor = FetchDescriptor<Task>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
