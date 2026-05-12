import Foundation
import SwiftData

@MainActor
enum OnboardingPersistence {
    /// Commits the in-memory draft to AppStore (UserDefaults) and SwiftData on Step 19.
    /// This is the only point where onboarding state becomes permanent.
    static func commit(draft: OnboardingDraft, store: AppStore, modelContext: ModelContext) {
        // Profile fields
        store.marketingOptIn = draft.marketingOptIn
        store.primaryNeed = draft.primaryNeed
        store.neurodivergenceSelfId = draft.neurodivergenceSelfId
        store.notificationsEnabled = draft.notificationsGranted
        store.calendarImported = draft.calendarGranted
        store.appleUserIdentifier = draft.appleUserIdentifier
        store.userEmail = draft.userEmail

        // Routines → SwiftData. Each onboarding slot maps to a default
        // `RoutineGroup` ("Morning routine" / "Afternoon routine" /
        // "Evening routine"), recurring daily. Groups are only created for
        // slots the user actually picked at least one routine in, so we
        // don't litter the home tab with empty groups.
        let userID = AuthManager.shared.currentUserID
        func ensureGroup(for slot: RoutineSlot) -> RoutineGroup {
            let g = RoutineGroup(
                title: RoutineScheduler.defaultGroupTitle(for: slot),
                slot: slot,
                recurrence: .daily,
                userID: userID
            )
            modelContext.insert(g)
            return g
        }

        var groupBySlot: [RoutineSlot: RoutineGroup] = [:]
        if !draft.morningRoutines.isEmpty   { groupBySlot[.morning]   = ensureGroup(for: .morning) }
        if !draft.afternoonRoutines.isEmpty { groupBySlot[.afternoon] = ensureGroup(for: .afternoon) }
        if !draft.eveningRoutines.isEmpty   { groupBySlot[.evening]   = ensureGroup(for: .evening) }

        for opt in draft.morningRoutines {
            modelContext.insert(RoutineTag(
                emoji: opt.emoji, label: opt.label, slot: .morning,
                userID: userID, groupID: groupBySlot[.morning]?.id
            ))
        }
        for opt in draft.afternoonRoutines {
            modelContext.insert(RoutineTag(
                emoji: opt.emoji, label: opt.label, slot: .afternoon,
                userID: userID, groupID: groupBySlot[.afternoon]?.id
            ))
        }
        for opt in draft.eveningRoutines {
            modelContext.insert(RoutineTag(
                emoji: opt.emoji, label: opt.label, slot: .evening,
                userID: userID, groupID: groupBySlot[.evening]?.id
            ))
        }

        // Selected AI tasks → SwiftData (Foggy is non-assignable; default to .steady)
        for d in draft.selectedTasks {
            let energy = d.suggestedEnergy ?? .steady
            modelContext.insert(Task(title: d.title, energyTag: energy))
        }

        modelContext.saveAndSync()

        // Materialize today's routine instances immediately so the user sees
        // their selected habits as scheduled tasks on first home-screen load,
        // without waiting for the next app foreground.
        RoutineScheduler.materializeToday(
            context: modelContext,
            userID: AuthManager.shared.currentUserID
        )
    }
}
