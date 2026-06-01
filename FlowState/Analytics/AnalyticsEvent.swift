import Foundation

/// Strongly-typed event taxonomy. See analytics/events-index.md for the
/// authoritative catalogue. Adding a new case requires updating that file.
///
/// The associated values are the event properties — they get flattened
/// into [String: Any] via `properties`. Keep keys snake_case.
enum AnalyticsEvent {

    // MARK: Lifecycle
    case appLaunched(cold: Bool, hasSession: Bool, entitled: Bool, appVersion: String, build: String)
    case appForegrounded(hoursSinceLastActive: Double)
    case appBackgrounded

    // MARK: Onboarding
    case onboardingStarted
    case onboardingStepViewed(step: Int, name: String)
    case onboardingStepCompleted(step: Int, name: String)
    case onboardingSkipped(fromStep: Int, name: String)
    case onboardingMarketingOptIn(value: Bool)
    case onboardingPrimaryNeed(value: String)
    case onboardingNeurodivergence(value: String)
    case onboardingAccountCreated(method: String)
    case onboardingPaywallCompleted(entitled: Bool)
    case onboardingNotificationsChoice(granted: Bool)
    case onboardingCalendarImported(eventCount: Int, granted: Bool)
    case onboardingRoutinesPicked(morning: Int, afternoon: Int, evening: Int)
    case onboardingRatingResponded(action: String)
    case onboardingWeeklyPlansEntered(taskCount: Int)
    case onboardingTasksGenerated(taskCount: Int, durationMs: Int)
    case onboardingTasksSelected(selected: Int, total: Int)
    case onboardingCommitted
    case onboardingCompleted(totalSteps: Int, routinesCount: Int, tasksCount: Int)

    // MARK: Auth
    case signupStarted(method: String)
    case signupCompleted(method: String, userID: String)
    case signupFailed(method: String, reason: String, httpStatus: Int?)
    case signinStarted(method: String)
    case signinCompleted(method: String, userID: String)
    case signinFailed(method: String, reason: String, httpStatus: Int?)
    case signout
    case accountDeleted
    case sessionRefreshFailed(reason: String)

    // MARK: Paywall (CRITICAL — see appsflyer-spec.md)
    case paywallShown(source: String, offeringsLoaded: Bool)
    case paywallOfferingsLoaded(packageCount: Int, latencyMs: Int)
    case paywallOfferingsFailed(error: String)
    case paywallPackageSelected(packageID: String, price: Double, currency: String, hasTrial: Bool)
    case paywallPurchaseInitiated(packageID: String, price: Double, currency: String, hasTrial: Bool)
    case paywallPurchaseCompleted(packageID: String, currency: String, isTrial: Bool)
    case paywallPurchaseCancelled(packageID: String)
    case paywallPurchaseFailed(packageID: String, error: String)
    case paywallRestoreInitiated
    case paywallRestoreCompleted(entitled: Bool)
    case paywallRestoreFailed(error: String)
    case paywallTermsTapped
    case paywallPrivacyTapped
    case paywallDismissed(source: String, action: String)
    case entitlementChanged(entitled: Bool, source: String)

    // MARK: Task loop
    case taskCreated(source: String, energyLevel: String?, hasDuration: Bool)
    case taskEdited(taskID: String, changedFields: [String])
    case taskDeleted(taskID: String, wasRoutine: Bool)
    case routineGroupDeleted(slot: String, taskCount: Int)
    case taskParked(taskID: String, elapsedSeconds: Int)
    case taskResumed(taskID: String, parkedDurationSeconds: Int)
    case taskScheduled(taskID: String, scheduledFor: String)
    case timerStarted(taskID: String, durationSeconds: Int?, mode: String)
    case timerDurationChanged(taskID: String, newDurationSeconds: Int?)
    case timerCompleted(taskID: String, elapsedSeconds: Int)
    case taskCompleted(taskID: String, durationSeconds: Int, energyLevel: String?, via: String)
    case completionDialogShown(taskID: String)
    case completionDialogDismissed(taskID: String, method: String)
    case energySet(level: String, source: String)
    case energyChanged(from: String, to: String, source: String)
    case foggyRestChosen
    case foggyPeekStarted
    case energySwitcherOpened
    case addTaskSheetOpened(source: String)

    // MARK: Routines
    case routineCreated(slot: String, tagCount: Int)
    case routineEdited(routineID: String, changedFields: [String])
    case routineMaterialized(slot: String, count: Int)

    // MARK: Calendar
    case calendarImportStarted
    case calendarImportSucceeded(eventCount: Int, latencyMs: Int)
    case calendarImportFailed(reason: String)

    // MARK: Chat / AI
    case chatMessageSent(lengthChars: Int, isVoice: Bool)
    case chatCommandExecuted(command: String)
    case chatQuotaExceeded(resetsAt: String?)
    case speechRecognitionStarted
    case speechRecognitionSucceeded(durationMs: Int, charCount: Int)
    case speechRecognitionFailed(reason: String)
    case aiClassifyEnergy(latencyMs: Int, outcome: String)

    // MARK: Settings
    case settingsOpened
    case themeChanged(value: String)
    case notificationsToggled(value: Bool)
    case subscriptionManageTapped
    case goProTapped
    case signoutConfirmed
    case deleteAccountConfirmed
    case reviewPromptInSettingsTapped

    // MARK: Permissions
    case notificationsPermissionRequested
    case notificationsPermissionResult(granted: Bool)
    case calendarPermissionRequested
    case calendarPermissionResult(granted: Bool)
    case attPermissionRequested
    case attPermissionResult(status: String)

    // MARK: Engagement / system
    case reviewPromptShown
    case notificationTap(type: String)
    case routineRemindersCapped(droppedCount: Int)
    case taskRemindersCapped(droppedCount: Int)
    case liveActivityStarted(taskID: String, durationSeconds: Int)
    case liveActivityEnded(taskID: String, reason: String)
    case liveActivityFailed(reason: String)
    case syncRunStarted(kind: String)
    case syncRunSucceeded(latencyMs: Int, recordCount: Int)
    case syncRunFailed(kind: String, reason: String)
    case tooltipShown(tipID: String)
    case tooltipDismissed(tipID: String)
    case deepLinkOpened(scheme: String, source: String)
    case appsFlyerConversion(properties: [String: Any])

    // MARK: - Mapping

    /// PostHog event name (snake_case).
    var name: String {
        switch self {
        case .appLaunched: return "app_launched"
        case .appForegrounded: return "app_foregrounded"
        case .appBackgrounded: return "app_backgrounded"
        case .onboardingStarted: return "onboarding_started"
        case .onboardingStepViewed: return "onboarding_step_viewed"
        case .onboardingStepCompleted: return "onboarding_step_completed"
        case .onboardingSkipped: return "onboarding_skipped"
        case .onboardingMarketingOptIn: return "onboarding_marketing_optin"
        case .onboardingPrimaryNeed: return "onboarding_primary_need"
        case .onboardingNeurodivergence: return "onboarding_neurodivergence"
        case .onboardingAccountCreated: return "onboarding_account_created"
        case .onboardingPaywallCompleted: return "onboarding_paywall_completed"
        case .onboardingNotificationsChoice: return "onboarding_notifications_choice"
        case .onboardingCalendarImported: return "onboarding_calendar_imported"
        case .onboardingRoutinesPicked: return "onboarding_routines_picked"
        case .onboardingRatingResponded: return "onboarding_rating_responded"
        case .onboardingWeeklyPlansEntered: return "onboarding_weekly_plans_entered"
        case .onboardingTasksGenerated: return "onboarding_tasks_generated"
        case .onboardingTasksSelected: return "onboarding_tasks_selected"
        case .onboardingCommitted: return "onboarding_committed"
        case .onboardingCompleted: return "onboarding_completed"
        case .signupStarted: return "signup_started"
        case .signupCompleted: return "signup_completed"
        case .signupFailed: return "signup_failed"
        case .signinStarted: return "signin_started"
        case .signinCompleted: return "signin_completed"
        case .signinFailed: return "signin_failed"
        case .signout: return "signout"
        case .accountDeleted: return "account_deleted"
        case .sessionRefreshFailed: return "session_refresh_failed"
        case .paywallShown: return "paywall_shown"
        case .paywallOfferingsLoaded: return "paywall_offerings_loaded"
        case .paywallOfferingsFailed: return "paywall_offerings_failed"
        case .paywallPackageSelected: return "paywall_package_selected"
        case .paywallPurchaseInitiated: return "paywall_purchase_initiated"
        case .paywallPurchaseCompleted: return "paywall_purchase_completed"
        case .paywallPurchaseCancelled: return "paywall_purchase_cancelled"
        case .paywallPurchaseFailed: return "paywall_purchase_failed"
        case .paywallRestoreInitiated: return "paywall_restore_initiated"
        case .paywallRestoreCompleted: return "paywall_restore_completed"
        case .paywallRestoreFailed: return "paywall_restore_failed"
        case .paywallTermsTapped: return "paywall_terms_tapped"
        case .paywallPrivacyTapped: return "paywall_privacy_tapped"
        case .paywallDismissed: return "paywall_dismissed"
        case .entitlementChanged: return "entitlement_changed"
        case .taskCreated: return "task_created"
        case .taskEdited: return "task_edited"
        case .taskDeleted: return "task_deleted"
        case .routineGroupDeleted: return "routine_group_deleted"
        case .taskParked: return "task_parked"
        case .taskResumed: return "task_resumed"
        case .taskScheduled: return "task_scheduled"
        case .timerStarted: return "timer_started"
        case .timerDurationChanged: return "timer_duration_changed"
        case .timerCompleted: return "timer_completed"
        case .taskCompleted: return "task_completed"
        case .completionDialogShown: return "completion_dialog_shown"
        case .completionDialogDismissed: return "completion_dialog_dismissed"
        case .energySet: return "energy_set"
        case .energyChanged: return "energy_changed"
        case .foggyRestChosen: return "foggy_rest_chosen"
        case .foggyPeekStarted: return "foggy_peek_started"
        case .energySwitcherOpened: return "energy_switcher_opened"
        case .addTaskSheetOpened: return "add_task_sheet_opened"
        case .routineCreated: return "routine_created"
        case .routineEdited: return "routine_edited"
        case .routineMaterialized: return "routine_materialized"
        case .calendarImportStarted: return "calendar_import_started"
        case .calendarImportSucceeded: return "calendar_import_succeeded"
        case .calendarImportFailed: return "calendar_import_failed"
        case .chatMessageSent: return "chat_message_sent"
        case .chatCommandExecuted: return "chat_command_executed"
        case .chatQuotaExceeded: return "chat_quota_exceeded"
        case .speechRecognitionStarted: return "speech_recognition_started"
        case .speechRecognitionSucceeded: return "speech_recognition_succeeded"
        case .speechRecognitionFailed: return "speech_recognition_failed"
        case .aiClassifyEnergy: return "ai_classify_energy"
        case .settingsOpened: return "settings_opened"
        case .themeChanged: return "theme_changed"
        case .notificationsToggled: return "notifications_toggled"
        case .subscriptionManageTapped: return "subscription_manage_tapped"
        case .goProTapped: return "go_pro_tapped"
        case .signoutConfirmed: return "signout_confirmed"
        case .deleteAccountConfirmed: return "delete_account_confirmed"
        case .reviewPromptInSettingsTapped: return "review_prompt_in_settings_tapped"
        case .notificationsPermissionRequested: return "notifications_permission_requested"
        case .notificationsPermissionResult: return "notifications_permission_result"
        case .calendarPermissionRequested: return "calendar_permission_requested"
        case .calendarPermissionResult: return "calendar_permission_result"
        case .attPermissionRequested: return "att_permission_requested"
        case .attPermissionResult: return "att_permission_result"
        case .reviewPromptShown: return "review_prompt_shown"
        case .notificationTap: return "notification_tap"
        case .routineRemindersCapped: return "routine_reminders_capped"
        case .taskRemindersCapped: return "task_reminders_capped"
        case .liveActivityStarted: return "live_activity_started"
        case .liveActivityEnded: return "live_activity_ended"
        case .liveActivityFailed: return "live_activity_failed"
        case .syncRunStarted: return "sync_run_started"
        case .syncRunSucceeded: return "sync_run_succeeded"
        case .syncRunFailed: return "sync_run_failed"
        case .tooltipShown: return "tooltip_shown"
        case .tooltipDismissed: return "tooltip_dismissed"
        case .deepLinkOpened: return "deep_link_opened"
        case .appsFlyerConversion: return "appsflyer_conversion"
        }
    }

    /// Property dict for PostHog `capture(_:properties:)`.
    var properties: [String: Any] {
        switch self {
        case let .appLaunched(cold, hasSession, entitled, appVersion, build):
            return ["cold": cold, "has_session": hasSession, "entitled": entitled,
                    "app_version": appVersion, "build": build]
        case let .appForegrounded(hours): return ["hours_since_last_active": hours]
        case .appBackgrounded: return [:]
        case .onboardingStarted: return [:]
        case let .onboardingStepViewed(step, name): return ["step": step, "step_name": name]
        case let .onboardingStepCompleted(step, name): return ["step": step, "step_name": name]
        case let .onboardingSkipped(step, name): return ["from_step": step, "step_name": name]
        case let .onboardingMarketingOptIn(value): return ["value": value]
        case let .onboardingPrimaryNeed(value): return ["value": value]
        case let .onboardingNeurodivergence(value): return ["value": value]
        case let .onboardingAccountCreated(method): return ["method": method]
        case let .onboardingPaywallCompleted(entitled): return ["entitled": entitled]
        case let .onboardingNotificationsChoice(granted): return ["granted": granted]
        case let .onboardingCalendarImported(count, granted): return ["event_count": count, "granted": granted]
        case let .onboardingRoutinesPicked(m, a, e): return ["morning_count": m, "afternoon_count": a, "evening_count": e]
        case let .onboardingRatingResponded(action): return ["action": action]
        case let .onboardingWeeklyPlansEntered(c): return ["task_count": c]
        case let .onboardingTasksGenerated(c, d): return ["task_count": c, "duration_ms": d]
        case let .onboardingTasksSelected(s, t): return ["selected_count": s, "total_count": t]
        case .onboardingCommitted: return [:]
        case let .onboardingCompleted(steps, routines, tasks):
            return ["total_steps": steps, "routines_count": routines, "tasks_count": tasks]
        case let .signupStarted(m): return ["method": m]
        case let .signupCompleted(m, uid): return ["method": m, "user_id": uid]
        case let .signupFailed(m, r, s):
            var d: [String: Any] = ["method": m, "reason": r]
            if let s { d["http_status"] = s }
            return d
        case let .signinStarted(m): return ["method": m]
        case let .signinCompleted(m, uid): return ["method": m, "user_id": uid]
        case let .signinFailed(m, r, s):
            var d: [String: Any] = ["method": m, "reason": r]
            if let s { d["http_status"] = s }
            return d
        case .signout, .accountDeleted: return [:]
        case let .sessionRefreshFailed(r): return ["reason": r]
        case let .paywallShown(source, loaded): return ["source": source, "offerings_loaded": loaded]
        case let .paywallOfferingsLoaded(c, l): return ["package_count": c, "latency_ms": l]
        case let .paywallOfferingsFailed(e): return ["error": e]
        case let .paywallPackageSelected(p, price, cur, t):
            return ["package_id": p, "price": price, "currency": cur, "has_trial": t]
        case let .paywallPurchaseInitiated(p, price, cur, t):
            return ["package_id": p, "price": price, "currency": cur, "has_trial": t]
        case let .paywallPurchaseCompleted(p, c, t):
            return ["package_id": p, "currency": c, "is_trial": t]
        case let .paywallPurchaseCancelled(p): return ["package_id": p]
        case let .paywallPurchaseFailed(p, e): return ["package_id": p, "error": e]
        case .paywallRestoreInitiated: return [:]
        case let .paywallRestoreCompleted(e): return ["entitled": e]
        case let .paywallRestoreFailed(e): return ["error": e]
        case .paywallTermsTapped, .paywallPrivacyTapped: return [:]
        case let .paywallDismissed(s, a): return ["source": s, "action": a]
        case let .entitlementChanged(e, s): return ["entitled": e, "source": s]
        case let .taskCreated(s, e, d):
            var props: [String: Any] = ["source": s, "has_duration": d]
            if let e { props["energy_level"] = e }
            return props
        case let .taskEdited(id, fields): return ["task_id": id, "changed_fields": fields]
        case let .taskDeleted(id, r): return ["task_id": id, "was_routine": r]
        case let .routineGroupDeleted(s, c): return ["slot": s, "task_count": c]
        case let .taskParked(id, e): return ["task_id": id, "elapsed_seconds": e]
        case let .taskResumed(id, d): return ["task_id": id, "parked_duration_seconds": d]
        case let .taskScheduled(id, d): return ["task_id": id, "scheduled_for_date": d]
        case let .timerStarted(id, d, m):
            var p: [String: Any] = ["task_id": id, "mode": m]
            if let d { p["duration_seconds"] = d }
            return p
        case let .timerDurationChanged(id, d):
            var p: [String: Any] = ["task_id": id]
            if let d { p["new_duration_seconds"] = d }
            return p
        case let .timerCompleted(id, e): return ["task_id": id, "elapsed_seconds": e]
        case let .taskCompleted(id, d, e, v):
            var p: [String: Any] = ["task_id": id, "duration_seconds": d, "via": v]
            if let e { p["energy_level"] = e }
            return p
        case let .completionDialogShown(id): return ["task_id": id]
        case let .completionDialogDismissed(id, m): return ["task_id": id, "method": m]
        case let .energySet(l, s): return ["level": l, "source": s]
        case let .energyChanged(f, t, s): return ["from": f, "to": t, "source": s]
        case .foggyRestChosen, .foggyPeekStarted, .energySwitcherOpened: return [:]
        case let .addTaskSheetOpened(s): return ["source": s]
        case let .routineCreated(s, c): return ["slot": s, "tag_count": c]
        case let .routineEdited(id, f): return ["routine_id": id, "changed_fields": f]
        case let .routineMaterialized(s, c): return ["slot": s, "count": c]
        case .calendarImportStarted: return [:]
        case let .calendarImportSucceeded(c, l): return ["event_count": c, "latency_ms": l]
        case let .calendarImportFailed(r): return ["reason": r]
        case let .chatMessageSent(l, v): return ["length_chars": l, "is_voice": v]
        case let .chatCommandExecuted(c): return ["command": c]
        case let .chatQuotaExceeded(r):
            var d: [String: Any] = [:]
            if let r { d["resets_at"] = r }
            return d
        case .speechRecognitionStarted: return [:]
        case let .speechRecognitionSucceeded(d, c): return ["duration_ms": d, "char_count": c]
        case let .speechRecognitionFailed(r): return ["reason": r]
        case let .aiClassifyEnergy(l, o): return ["latency_ms": l, "outcome": o]
        case .settingsOpened, .subscriptionManageTapped, .goProTapped,
             .signoutConfirmed, .deleteAccountConfirmed, .reviewPromptInSettingsTapped:
            return [:]
        case let .themeChanged(v): return ["value": v]
        case let .notificationsToggled(v): return ["value": v]
        case .notificationsPermissionRequested, .calendarPermissionRequested,
             .attPermissionRequested, .reviewPromptShown:
            return [:]
        case let .notificationsPermissionResult(g): return ["granted": g]
        case let .calendarPermissionResult(g): return ["granted": g]
        case let .attPermissionResult(s): return ["status": s]
        case let .notificationTap(t): return ["type": t]
        case let .routineRemindersCapped(c): return ["dropped_count": c]
        case let .taskRemindersCapped(c): return ["dropped_count": c]
        case let .liveActivityStarted(id, d): return ["task_id": id, "duration_seconds": d]
        case let .liveActivityEnded(id, r): return ["task_id": id, "reason": r]
        case let .liveActivityFailed(r): return ["reason": r]
        case let .syncRunStarted(k): return ["kind": k]
        case let .syncRunSucceeded(l, c): return ["latency_ms": l, "record_count": c]
        case let .syncRunFailed(k, r): return ["kind": k, "reason": r]
        case let .tooltipShown(id): return ["tip_id": id]
        case let .tooltipDismissed(id): return ["tip_id": id]
        case let .deepLinkOpened(s, src): return ["scheme": s, "source": src]
        case let .appsFlyerConversion(props): return props
        }
    }

    /// AppsFlyer mapping. Returns nil for events we only fire to PostHog.
    /// Revenue events (`af_purchase`, `af_start_trial`, `af_subscribe`) are
    /// **deliberately absent** — they come from RC's S2S integration. Sending
    /// them from the client too would double-count. See appsflyer-spec.md §3.
    var appsFlyerMapping: (name: String, values: [String: Any])? {
        switch self {
        case let .signupCompleted(method, _):
            return ("af_complete_registration", ["af_registration_method": method])
        case let .signinCompleted(method, _):
            return ("af_login", ["af_login_method": method])
        case .paywallShown:
            return ("af_content_view", ["af_content_id": "paywall", "af_content_type": "paywall_view"])
        case let .paywallPackageSelected(pkg, price, currency, _):
            return ("af_content_view", [
                "af_content_id": pkg, "af_content_type": "package",
                "af_price": price, "af_currency": currency,
            ])
        case let .paywallPurchaseInitiated(pkg, price, currency, trial):
            return ("af_initiated_checkout", [
                "af_content_id": pkg, "af_price": price, "af_currency": currency,
                "af_quantity": 1, "has_trial": trial,
            ])
        case .paywallRestoreInitiated:
            return ("af_initiated_checkout", ["af_content_type": "restore"])
        case let .onboardingCompleted(steps, routines, tasks):
            return ("onboarding_completed", [
                "step_count": steps, "routines_count": routines, "tasks_count": tasks,
            ])
        case let .taskCompleted(_, d, energy, _):
            var v: [String: Any] = ["duration_seconds": d]
            if let energy { v["energy_level"] = energy }
            return ("task_completed", v)
        case let .taskCreated(source, energy, _):
            var v: [String: Any] = ["source": source]
            if let energy { v["energy_level"] = energy }
            return ("task_created", v)
        default:
            return nil
        }
    }
}
