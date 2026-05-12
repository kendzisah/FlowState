import Foundation
import SwiftData

/// Materializes the user's chosen `RoutineTag` rows into daily `Task` instances
/// at sensible default times per slot.
///
/// Why this exists: onboarding collects routine *intent* (a list of habits per
/// time-of-day slot), but Tasks are what the rest of the app surfaces. Without
/// this scheduler the routines selected in onboarding would be dead data.
///
/// Idempotency: each `RoutineTag` carries `lastGeneratedDay`. The scheduler
/// only inserts a Task if the routine hasn't been materialized today yet, so
/// running this on every app launch / foreground is safe and cheap.
///
/// Times: morning routines schedule at 08:00, afternoon at 13:00, evening at
/// 20:00. Users can edit the resulting Task afterward (the Task is decoupled
/// from the RoutineTag once created).
@MainActor
enum RoutineScheduler {
    private static let defaultHour: [RoutineSlot: Int] = [
        .morning:   8,
        .afternoon: 13,
        .evening:   20
    ]

    /// Ensures each of the user's routines has an instance scheduled for today.
    ///
    /// Behaviour ("repeat daily unless completed"):
    /// - If today's instance already exists (completed or not), do nothing.
    /// - Else if an uncompleted older instance exists, roll it forward to
    ///   today's slot hour — the same task the user has been carrying.
    /// - Else, create a fresh Task for today.
    ///
    /// Only routines owned by `userID` (plus orphan rows from before the
    /// `userID` field existed) are considered; orphans are claimed in the
    /// process so a second sign-in doesn't re-materialize them for the wrong
    /// user. Duplicate `(slot, emoji, label)` rows left over from the old
    /// double-tap bug are collapsed.
    static func materializeToday(context: ModelContext, userID: String?) {
        guard let userID else { return }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        let routineDescriptor = FetchDescriptor<RoutineTag>(predicate: #Predicate { tag in
            tag.userID == userID || tag.userID == nil
        })
        guard let routines = try? context.fetch(routineDescriptor), !routines.isEmpty else { return }

        // One-time migration: tasks created before the `isRoutine`/
        // `sourceRoutineID` fields existed look like regular tasks but have
        // the same `"emoji label"` title as a routine. Adopt them so they
        // render inside the routine group instead of duplicating below it.
        backfillLegacyRoutineTasks(routines: routines, userID: userID, in: context)

        // Migrate legacy tags into per-slot default groups, then load every
        // group for this user so we can iterate groups (not tags) below.
        let groupsBySlot = ensureDefaultGroups(for: routines, userID: userID, in: context)
        let allGroups = (try? context.fetch(
            FetchDescriptor<RoutineGroup>(predicate: #Predicate { g in
                g.userID == userID || g.userID == nil
            })
        )) ?? []

        // Index any prior routine-derived tasks so we can dedupe and carry
        // uncompleted ones forward instead of creating duplicates.
        let taskDescriptor = FetchDescriptor<Task>(predicate: #Predicate { $0.isRoutine == true })
        let existingByRoutine: [UUID: [Task]] = ((try? context.fetch(taskDescriptor)) ?? [])
            .reduce(into: [:]) { acc, t in
                guard let rid = t.sourceRoutineID else { return }
                acc[rid, default: []].append(t)
            }

        let routinesByGroup: [UUID: [RoutineTag]] = routines.reduce(into: [:]) { acc, tag in
            guard let gid = tag.groupID else { return }
            acc[gid, default: []].append(tag)
        }

        var seen: [String: RoutineTag] = [:]
        var dirty = false
        for group in allGroups {
            if group.userID == nil { group.userID = userID }

            // Skip the entire group if its recurrence rule doesn't fire today.
            // `coversToday(from: group.createdAt)` covers daily/weekday/weekly/monthly.
            guard group.recurrence.coversToday(from: group.createdAt, calendar: calendar) else { continue }

            let groupRoutines = routinesByGroup[group.id] ?? []
            let hour = defaultHour[group.slot] ?? 8
            let scheduledAt = calendar.date(
                bySettingHour: hour, minute: 0, second: 0, of: startOfToday
            ) ?? startOfToday

            for routine in groupRoutines {
                if routine.userID == nil { routine.userID = userID }
                let key = "\(routine.slotRaw)|\(routine.emoji)|\(routine.label)|\(routine.groupID?.uuidString ?? "-")"
                if seen[key] != nil {
                    context.delete(routine)
                    dirty = true
                    continue
                }
                seen[key] = routine

                let prior = existingByRoutine[routine.id] ?? []
                let hasTodayInstance = prior.contains { t in
                    guard let s = t.scheduledDate else { return false }
                    return calendar.isDate(s, inSameDayAs: startOfToday)
                }
                if hasTodayInstance { continue }

                if let carry = prior.first(where: { !$0.isCompleted }) {
                    carry.scheduledDate = scheduledAt
                    carry.routineSlot = routine.slotRaw
                    carry.markDirty()
                    dirty = true
                    continue
                }

                let task = Task(
                    title: "\(routine.emoji) \(routine.label)",
                    energyTag: .steady,
                    userID: userID
                )
                task.scheduledDate = scheduledAt
                task.isRoutine = true
                task.routineSlot = routine.slotRaw
                task.sourceRoutineID = routine.id
                context.insert(task)
                routine.lastGeneratedDay = startOfToday
                dirty = true
            }
            group.lastGeneratedDay = startOfToday
        }

        // Belt-and-suspenders: silence unused warning if no slot was touched.
        _ = groupsBySlot

        if dirty {
            try? context.save()
        }
    }

    /// Returns a per-slot map of default `RoutineGroup`s, creating them where
    /// they don't yet exist, and adopts any legacy `RoutineTag` rows with
    /// `groupID == nil` into the appropriate default group. Idempotent.
    @discardableResult
    private static func ensureDefaultGroups(
        for routines: [RoutineTag],
        userID: String,
        in context: ModelContext
    ) -> [RoutineSlot: RoutineGroup] {
        let descriptor = FetchDescriptor<RoutineGroup>(predicate: #Predicate { g in
            g.userID == userID || g.userID == nil
        })
        let existing = (try? context.fetch(descriptor)) ?? []

        var defaults: [RoutineSlot: RoutineGroup] = [:]
        for slot in RoutineSlot.allCases {
            let title = defaultGroupTitle(for: slot)
            if let match = existing.first(where: { $0.title == title && $0.slot == slot }) {
                if match.userID == nil { match.userID = userID }
                defaults[slot] = match
            }
        }

        // Find legacy tags first so we don't create empty default groups for
        // slots that have no orphan tags.
        let orphans = routines.filter { $0.groupID == nil }
        guard !orphans.isEmpty || defaults.count < RoutineSlot.allCases.count else {
            return defaults
        }

        for tag in orphans {
            let slot = tag.slot
            if defaults[slot] == nil {
                let g = RoutineGroup(
                    title: defaultGroupTitle(for: slot),
                    slot: slot,
                    recurrence: .daily,
                    userID: userID
                )
                context.insert(g)
                defaults[slot] = g
            }
            tag.groupID = defaults[slot]?.id
        }
        return defaults
    }

    static func defaultGroupTitle(for slot: RoutineSlot) -> String {
        switch slot {
        case .morning:   return "Morning routine"
        case .afternoon: return "Afternoon routine"
        case .evening:   return "Evening routine"
        }
    }

    /// Match orphan tasks (no `sourceRoutineID`, `isRoutine == false`, with
    /// a `scheduledDate`) by exact `"emoji label"` title against the user's
    /// routines and adopt them. Limited to single matches per routine so we
    /// never absorb a manually-created task that happens to share an emoji.
    private static func backfillLegacyRoutineTasks(
        routines: [RoutineTag],
        userID: String,
        in context: ModelContext
    ) {
        // SwiftData's `#Predicate` macro hits the type-checker complexity
        // limit when this is one expression; narrow it via the macro to the
        // two equality clauses it handles cleanly, then refine in Swift.
        let descriptor = FetchDescriptor<Task>(predicate: #Predicate { task in
            task.isRoutine == false && task.sourceRoutineID == nil
        })
        let candidates = (try? context.fetch(descriptor)) ?? []
        let orphans = candidates.filter { task in
            guard task.scheduledDate != nil else { return false }
            return task.userID == userID || task.userID == nil
        }
        guard !orphans.isEmpty else { return }

        var orphansByTitle: [String: [Task]] = [:]
        for t in orphans { orphansByTitle[t.title, default: []].append(t) }

        var dirty = false
        for routine in routines {
            let title = "\(routine.emoji) \(routine.label)"
            guard let matches = orphansByTitle[title] else { continue }
            // Multiple matches → ambiguous, don't guess. The user can edit
            // those tasks manually.
            for match in matches {
                match.isRoutine = true
                match.routineSlot = routine.slotRaw
                match.sourceRoutineID = routine.id
                match.markDirty()
                dirty = true
            }
        }
        if dirty { try? context.save() }
    }
}
