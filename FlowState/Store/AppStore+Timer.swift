import Foundation
import SwiftData
import UIKit

extension AppStore {
    /// Caller-supplied "now" so background-foreground math can pass the foreground time.
    func currentElapsed() -> Int {
        switch timerMode {
        case .countdown:
            return max(timerDurationSeconds - timerSecondsRemaining, 0)
        case .countup:
            return timerElapsedSeconds
        }
    }

    func startTask(_ task: Task) {
        activeTask = task
        timerElapsedSeconds = 0
        showDurationPicker = false
        showEnergySwitcher = false
        showAddTask = false

        if let preset = (energyLevel ?? .steady).defaultDurationSeconds {
            timerMode = .countdown
            timerDurationSeconds = preset
            timerSecondsRemaining = preset
        } else {
            timerMode = .countup
            timerDurationSeconds = 0
            timerSecondsRemaining = 0
        }

        Analytics.track(.timerStarted(
            taskID: task.id.uuidString,
            durationSeconds: timerMode == .countdown ? timerDurationSeconds : nil,
            mode: timerMode == .countdown ? "countdown" : "countup"
        ))

        timerRunning = true
        impactHaptic(.medium)
        startTicker()
        WidgetSnapshotWriter.refresh(store: self, context: nil)

        if notificationsEnabled {
            _Concurrency.Task { await NotificationManager.requestAuthorizationIfNeeded() }
            if timerMode == .countdown {
                NotificationManager.scheduleCompletion(after: timerSecondsRemaining)
            } else {
                NotificationManager.cancelCompletion()
            }
        } else {
            NotificationManager.cancelCompletion()
        }

        let energy = energyLevel ?? .steady
        LiveActivityController.start(
            taskID: task.id.uuidString,
            taskTitle: task.title,
            energyHex: energy.hexString,
            mode: timerMode,
            secondsRemaining: timerSecondsRemaining,
            secondsElapsed: timerElapsedSeconds,
            totalDuration: timerDurationSeconds
        )
    }

    func setTimerDuration(_ seconds: Int?) {
        let elapsed = currentElapsed()
        if let activeTask {
            Analytics.track(.timerDurationChanged(
                taskID: activeTask.id.uuidString,
                newDurationSeconds: seconds
            ))
        }

        if let newTotal = seconds {
            timerMode = .countdown
            timerDurationSeconds = newTotal
            timerSecondsRemaining = max(newTotal - elapsed, 0)
            timerElapsedSeconds = elapsed
            if notificationsEnabled {
                NotificationManager.scheduleCompletion(after: timerSecondsRemaining)
            }
            if timerSecondsRemaining == 0, let task = activeTask {
                completeTask(task, context: nil)
                return
            }
        } else {
            timerMode = .countup
            timerDurationSeconds = 0
            timerSecondsRemaining = 0
            timerElapsedSeconds = elapsed
            NotificationManager.cancelCompletion()
        }

        impactHaptic((energyLevel ?? .steady).hapticStyle)

        LiveActivityController.update(
            mode: timerMode,
            secondsRemaining: timerSecondsRemaining,
            secondsElapsed: timerElapsedSeconds
        )
    }

    func tick() {
        guard timerRunning else { return }
        switch timerMode {
        case .countdown:
            timerSecondsRemaining = max(timerSecondsRemaining - 1, 0)
            if timerSecondsRemaining == 0, let task = activeTask {
                completeTask(task, context: nil)
            }
        case .countup:
            timerElapsedSeconds += 1
        }
    }

    func startTicker() {
        ticker?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            _Concurrency.Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    func parkTask(context: ModelContext?) {
        guard let task = activeTask else { return }
        let elapsed = currentElapsed()
        Analytics.track(.taskParked(taskID: task.id.uuidString, elapsedSeconds: elapsed))
        let parked = ParkedTask(
            taskId: task.id,
            taskTitle: task.title,
            elapsedSeconds: elapsed
        )
        if let context {
            context.insert(parked)
            context.saveAndSync()
        }
        timerRunning = false
        stopTicker()
        activeTask = nil

        NotificationManager.cancelCompletion()
        // Flip the Live Activity into the Parked banner for the linger window
        // instead of ending it immediately — gives the user a glanceable
        // "I just parked X" confirmation on the lock screen.
        let parkedCount: Int = {
            guard let context else { return 0 }
            return (try? context.fetchCount(FetchDescriptor<ParkedTask>())) ?? 0
        }()
        LiveActivityController.setParked(parkedCount: parkedCount)
        impactHaptic(.light)
        resetEnergyForRePrompt()
        WidgetSnapshotWriter.refresh(store: self, context: context)
    }

    func completeTask(_ task: Task, context: ModelContext?) {
        let elapsed = currentElapsed()
        // Timer reaching zero / user tapping complete is the activation
        // signal for paid-acquisition cohorts. AppsFlyer's mapping uses
        // duration_seconds + energy_level for tighter ad optimisation.
        Analytics.track(.timerCompleted(taskID: task.id.uuidString, elapsedSeconds: elapsed))
        Analytics.track(.taskCompleted(
            taskID: task.id.uuidString,
            durationSeconds: elapsed,
            energyLevel: energyLevel?.rawValue,
            via: "timer"
        ))

        task.isCompleted = true
        task.completedAt = Date()
        if let context {
            context.saveAndSync()
        }
        timerRunning = false
        stopTicker()
        activeTask = nil

        NotificationManager.cancelCompletion()
        // Flip the Live Activity to "Session complete" for the linger window.
        LiveActivityController.setComplete()

        successHaptic()
        completionDialog = CompletionDialogState(taskTitle: task.title)

        ReviewPromptManager.recordTaskCompletion(store: self)
        WidgetSnapshotWriter.refresh(store: self, context: context)
    }

    func resumeParked(_ parked: ParkedTask, allTasks: [Task], context: ModelContext?) {
        guard let task = allTasks.first(where: { $0.id == parked.taskId }) else {
            if let context {
                context.delete(parked)
                context.saveAndSync()
            }
            return
        }
        Analytics.track(.taskResumed(
            taskID: task.id.uuidString,
            parkedDurationSeconds: parked.elapsedSeconds
        ))
        activeTask = task
        timerElapsedSeconds = parked.elapsedSeconds

        if let preset = (energyLevel ?? .steady).defaultDurationSeconds {
            timerMode = .countdown
            timerDurationSeconds = preset
            timerSecondsRemaining = max(preset - parked.elapsedSeconds, 0)
        } else {
            timerMode = .countup
            timerDurationSeconds = 0
            timerSecondsRemaining = 0
        }

        timerRunning = true
        if let context {
            context.delete(parked)
            context.saveAndSync()
        }
        startTicker()

        if notificationsEnabled, timerMode == .countdown {
            NotificationManager.scheduleCompletion(after: timerSecondsRemaining)
        } else {
            NotificationManager.cancelCompletion()
        }

        let energy = energyLevel ?? .steady
        LiveActivityController.start(
            taskID: task.id.uuidString,
            taskTitle: task.title,
            energyHex: energy.hexString,
            mode: timerMode,
            secondsRemaining: timerSecondsRemaining,
            secondsElapsed: timerElapsedSeconds,
            totalDuration: timerDurationSeconds
        )
        WidgetSnapshotWriter.refresh(store: self, context: context)
    }
}
