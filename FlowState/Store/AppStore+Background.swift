import Foundation
import SwiftUI

extension AppStore {
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background, .inactive:
            if timerRunning {
                backgroundedAt = Date()
                stopTicker()
            }
        case .active:
            applyForegroundDelta()
            if !timerRunning && shouldRepromptOnForeground() {
                resetEnergyForRePrompt()
            }
        @unknown default:
            break
        }
    }

    private func applyForegroundDelta() {
        guard let bg = backgroundedAt, timerRunning else {
            backgroundedAt = nil
            if timerRunning && ticker == nil { startTicker() }
            return
        }
        let delta = max(0, Int(Date().timeIntervalSince(bg)))
        switch timerMode {
        case .countdown:
            timerSecondsRemaining = max(0, timerSecondsRemaining - delta)
            // A routine run never auto-completes on the clock — hold at 0:00.
            if timerSecondsRemaining == 0, activeRoutineRun == nil, let task = activeTask {
                completeTask(task, context: nil)
                backgroundedAt = nil
                return
            }
        case .countup:
            timerElapsedSeconds += delta
        }
        backgroundedAt = nil
        startTicker()

        LiveActivityController.update(
            mode: timerMode,
            secondsRemaining: timerSecondsRemaining,
            secondsElapsed: timerElapsedSeconds
        )

        if notificationsEnabled, timerMode == .countdown, activeRoutineRun == nil {
            NotificationManager.scheduleCompletion(after: timerSecondsRemaining)
        }
    }
}
