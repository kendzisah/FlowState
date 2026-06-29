import SwiftUI
import SwiftData

struct CalendarTabView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ImportedEvent.startDate) private var everyEvent: [ImportedEvent]
    @Query(sort: \Task.scheduledDate) private var everyTask: [Task]
    @Query private var everyRoutine: [RoutineTag]
    @Query private var everyGroup: [RoutineGroup]

    private var allGroups: [RoutineGroup] {
        guard let uid = AuthManager.shared.currentUserID else { return [] }
        return everyGroup.filter { $0.userID == uid || $0.userID == nil }
    }

    /// Rows owned by the signed-in user. The Supabase RLS guarantees the
    /// server only ever returns the right rows; this filter just scopes
    /// whatever's already on disk (e.g. cached from a previous account).
    private var allEvents: [ImportedEvent] {
        guard let uid = AuthManager.shared.currentUserID else { return [] }
        return everyEvent.filter { $0.userID == uid }
    }
    private var allTasks: [Task] {
        guard let uid = AuthManager.shared.currentUserID else { return [] }
        return everyTask.filter { $0.userID == uid }
    }

    @State private var selectedDate: Date = Date()
    @State private var importInFlight = false
    @State private var importError: String?
    @State private var classifyInFlight = false

    // Inline composer state. When `composerActive` is true, the composer is
    // presented; new items are untimed (land in the "No set time" tray).
    @State private var composerActive: Bool = false
    @State private var composerTitle: String = ""
    @State private var composerEnergyOverride: EnergyLevel?
    @State private var composerRecurrence: Recurrence = .none

    @State private var showMonthPicker: Bool = false
    @State private var classifyingEventIDs: Set<UUID> = []
    @State private var isAutoSortingAnytime: Bool = false

    @State private var editingRoutine: RoutineTag?
    @State private var deletingRoutineTask: Task?
    @State private var addingInGroup: RoutineGroup?
    @State private var addingGroupSlot: RoutineSlot?
    @State private var editingGroup: RoutineGroup?
    @State private var deletingGroup: RoutineGroup?

    @State private var editingTask: Task?
    @State private var deletingTask: Task?
    @State private var reschedulingTask: Task?

    private let calendar = Calendar.current

    private var dayItems: [DayItem] {
        var items: [DayItem] = []
        for e in allEvents where CalendarDayBuckets.event(e, overlaps: selectedDate, calendar: calendar) {
            items.append(.event(e))
        }
        for t in allTasks where !t.isRoutine {
            if let occurrence = t.occurrenceDate(on: selectedDate, calendar: calendar) {
                items.append(.task(t, occurrenceDate: occurrence))
            }
        }
        return items
    }

    /// Routine groups for the selected day, flattened across slots. The
    /// timeline places each at its reminder time.
    private var allGroupEntries: [(group: RoutineGroup, tasks: [Task])] {
        groupsByDaySlot.values.flatMap { $0 }
    }

    /// The day split into a chronological timed list (events, task occurrences,
    /// routine groups) and a separate "no set time" list.
    private var timeline: (timed: [TimelineEntry], noSetTime: [DayItem]) {
        TimelineBuilder.build(items: dayItems, groups: allGroupEntries, on: selectedDate, calendar: calendar)
    }

    /// Routine groups (with their child tasks for `selectedDate`) keyed by
    /// the calendar's `DayTimeSlot`. Flattened by `allGroupEntries` and placed
    /// on the timeline at each group's reminder time.
    private var groupsByDaySlot: [DayTimeSlot: [(group: RoutineGroup, tasks: [Task])]] {
        let start = calendar.startOfDay(for: selectedDate)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [:] }

        let routineTasks = allTasks.filter { t in
            guard t.isRoutine, let s = t.scheduledDate else { return false }
            return s >= start && s < end
        }
        var byGroupID: [UUID: [Task]] = [:]
        for t in routineTasks {
            guard let rid = t.sourceRoutineID,
                  let tag = everyRoutine.first(where: { $0.id == rid }),
                  let gid = tag.groupID else { continue }
            byGroupID[gid, default: []].append(t)
        }

        let isToday = calendar.isDate(selectedDate, inSameDayAs: Date())
        var result: [DayTimeSlot: [(group: RoutineGroup, tasks: [Task])]] = [:]
        for group in allGroups {
            // Recurrence is anchored at the group's createdAt; selectedDate
            // may be past or future from "today" — use the calendar's day
            // arithmetic via a shifted Date helper.
            guard recurrenceCovers(group: group, day: selectedDate) else { continue }
            let target: DayTimeSlot
            switch group.slot {
            case .morning:   target = .morning
            case .afternoon: target = .afternoon
            case .evening:   target = .evening
            }
            let real = (byGroupID[group.id] ?? [])
                .sorted { ($0.scheduledDate ?? .distantPast) < ($1.scheduledDate ?? .distantPast) }
            // For non-today days with no materialized routine Tasks, synthesize
            // read-only ghost rows from the group's catalog so the user can
            // preview "what this day looks like" without us writing forward
            // Task rows for every day. `RoutineSlotSection`'s `isPreview` flag
            // suppresses the toggle interaction.
            let tasks: [Task]
            if !real.isEmpty {
                tasks = real
            } else if !isToday {
                tasks = ghostRoutineTasks(for: group, on: selectedDate)
            } else {
                tasks = []
            }
            result[target, default: []].append((group, tasks))
        }
        for key in result.keys {
            result[key]?.sort { $0.group.createdAt < $1.group.createdAt }
        }
        return result
    }

    /// Builds in-memory `Task` objects (NOT inserted into the context) that
    /// mirror what `RoutineScheduler.materializeToday` would create for `day`.
    /// These are display-only previews — the matching real Tasks come into
    /// existence on the day the user opens the app.
    private func ghostRoutineTasks(for group: RoutineGroup, on day: Date) -> [Task] {
        let tagsInGroup = everyRoutine.filter { $0.groupID == group.id }
        guard !tagsInGroup.isEmpty else { return [] }

        // Honor the group's actual reminder time so non-today preview rows land
        // at the same hour the real materialization (and notification) will use.
        let hour = group.reminderHour ?? TimelineBuilder.defaultHour(for: group.slot)
        let minute = group.reminderMinute ?? 0
        let dayStart = calendar.startOfDay(for: day)
        let scheduledAt = calendar.date(
            bySettingHour: hour, minute: minute, second: 0, of: dayStart
        ) ?? day
        let userID = AuthManager.shared.currentUserID

        return tagsInGroup.map { tag in
            let t = Task(
                title: "\(tag.emoji) \(tag.label)",
                energyTag: .steady,
                userID: userID
            )
            t.scheduledDate = scheduledAt
            t.isRoutine = true
            t.routineSlot = group.slotRaw
            t.sourceRoutineID = tag.id
            return t
        }
    }

    /// Variant of `Recurrence.coversToday` that targets an arbitrary day —
    /// useful for the calendar where the user can navigate to past or future
    /// dates. Just shifts the comparison day to `selectedDate`.
    private func recurrenceCovers(group: RoutineGroup, day: Date) -> Bool {
        let sourceDay = calendar.startOfDay(for: group.createdAt)
        let targetDay = calendar.startOfDay(for: day)
        if calendar.isDate(targetDay, inSameDayAs: sourceDay) { return true }
        guard targetDay > sourceDay else { return false }
        switch group.recurrence {
        case .none:     return false
        case .daily:    return true
        case .weekdays:
            let wd = calendar.component(.weekday, from: targetDay)
            return (2...6).contains(wd)
        case .weekly:
            return calendar.component(.weekday, from: targetDay)
                == calendar.component(.weekday, from: sourceDay)
        case .monthly:
            return calendar.component(.day, from: targetDay)
                == calendar.component(.day, from: sourceDay)
        }
    }

    var body: some View {
        @Bindable var bindable = store

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                topActions
                DayNavBar(selectedDate: $selectedDate) {
                    showMonthPicker = true
                }
                tipCardsRow
                noSetTimeTray
                dayTimeline
                newRoutineGroupButton
            }
            .padding(.horizontal, Geometry.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composerInset
        }
        .animation(.easeOut(duration: 0.22), value: composerActive)
        .sheet(isPresented: $showMonthPicker) {
            MonthPickerSheet(selectedDate: $selectedDate) {
                showMonthPicker = false
            }
            .environment(\.palette, palette)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Couldn't import calendar",
               isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } }),
               actions: { Button("OK", role: .cancel) {} },
               message: { Text(importError ?? "") })
        .routineSheets(
            editingRoutine: $editingRoutine,
            addingInGroup: $addingInGroup,
            addingGroupSlot: $addingGroupSlot,
            editingGroup: $editingGroup,
            palette: palette,
            todayInstance: { todayInstance(of: $0) }
        )
        .sheet(item: $editingTask) { task in
            AddTaskSheet(editing: task)
                .environment(\.palette, palette)
        }
        .sheet(item: $reschedulingTask) { task in
            ScheduleTaskSheet(task: task) {
                reschedulingTask = nil
            }
            .environment(\.palette, palette)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .alert(
            "Delete task?",
            isPresented: Binding(
                get: { deletingTask != nil },
                set: { if !$0 { deletingTask = nil } }
            ),
            presenting: deletingTask
        ) { task in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { performTaskDelete(task) }
        } message: { task in
            Text("\u{201C}\(task.title)\u{201D} will be removed. This can't be undone.")
        }
        .alert(
            "Delete routine?",
            isPresented: Binding(
                get: { deletingRoutineTask != nil },
                set: { if !$0 { deletingRoutineTask = nil } }
            ),
            presenting: deletingRoutineTask
        ) { task in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { performRoutineDelete(task) }
        } message: { task in
            Text("\u{201C}\(task.title)\u{201D} will stop repeating. Today's instance is removed too.")
        }
        .alert(
            "Delete this group?",
            isPresented: Binding(
                get: { deletingGroup != nil },
                set: { if !$0 { deletingGroup = nil } }
            ),
            presenting: deletingGroup
        ) { group in
            Button("Cancel", role: .cancel) { }
            Button("Delete all", role: .destructive) { performGroupDelete(group) }
        } message: { group in
            Text("Every routine in \u{201C}\(group.title)\u{201D} will stop repeating.")
        }
    }

    // MARK: - Composer

    @ViewBuilder
    private var composerInset: some View {
        if composerActive {
            CalendarItemComposer(
                title: $composerTitle,
                energyOverride: $composerEnergyOverride,
                recurrence: $composerRecurrence,
                onSubmit: { saveComposerTask() },
                onCancel: { dismissComposer() }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func openComposer() {
        composerTitle = ""
        composerEnergyOverride = nil
        composerRecurrence = .none
        composerActive = true
    }

    private func dismissComposer() {
        composerActive = false
        composerTitle = ""
        composerEnergyOverride = nil
        composerRecurrence = .none
    }

    private func saveComposerTask() {
        let trimmed = composerTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let energy = composerEnergyOverride ?? EventEnergyClassifier.heuristic(for: trimmed)
        let task = Task(title: trimmed, energyTag: energy)
        // New items are untimed: date-only placement on the selected day, which
        // lands them in the "No set time" tray (and the home's flexible energy
        // lane). The user pins a time later via Reschedule, which sets isAnchored.
        task.scheduledDate = calendar.startOfDay(for: selectedDate)
        task.isAnchored = false
        task.recurrence = composerRecurrence
        modelContext.insert(task)
        modelContext.saveAndSync()
        dismissComposer()
    }

    // MARK: - Top actions (auto-sort, add)

    private var topActions: some View {
        HStack(spacing: 12) {
            Spacer()
            if store.calendarImported {
                Button {
                    runCalendarImport()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                        .symbolEffect(.pulse, options: .repeating, isActive: importInFlight)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(palette.surface)
                                .overlay(Circle().stroke(palette.border, lineWidth: 1))
                        )
                        .opacity(importInFlight ? 0.6 : 1.0)
                }
                .buttonStyle(.pressable)
                .disabled(importInFlight)
                .accessibilityLabel(importInFlight ? "Refreshing calendar" : "Refresh calendar")
            }

            Button {
                runAutoSort()
            } label: {
                Image(systemName: classifyInFlight ? "sparkles" : "wand.and.stars")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(palette.surface)
                            .overlay(Circle().stroke(palette.border, lineWidth: 1))
                    )
                    .opacity(classifyInFlight ? 0.5 : 1.0)
            }
            .buttonStyle(.pressable)
            .disabled(classifyInFlight)
            .accessibilityLabel("Auto-sort events by energy")

            Button {
                openComposer()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(palette.surface)
                            .overlay(Circle().stroke(palette.border, lineWidth: 1))
                    )
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Add task")
        }
    }

    // MARK: - Tip cards

    @ViewBuilder
    private var tipCardsRow: some View {
        let showSmart = !store.tipSmartWidgetsDismissed
        let showImport = !store.tipImportCalendarDismissed && !store.calendarImported

        if showSmart || showImport {
            HStack(spacing: 12) {
                if showSmart {
                    TipCard(title: "Add smart widgets", systemImage: "rectangle.3.group") {
                        store.tipSmartWidgetsDismissed = true
                    } onTap: {
                        store.tipSmartWidgetsDismissed = true
                    }
                }
                if showImport {
                    TipCard(title: "Import your calendar", systemImage: "calendar") {
                        store.tipImportCalendarDismissed = true
                    } onTap: {
                        runCalendarImport()
                    }
                }
            }
        }
    }

    // MARK: - Day sections

    private var noSetTimeTray: some View {
        NoSetTimeTray(
            items: timeline.noSetTime,
            classifyingEventIDs: classifyingEventIDs,
            isAutoSorting: isAutoSortingAnytime,
            onPickEnergy: { item, level in applyEnergy(item, level: level) },
            onAutoClassify: { autoClassifyOne($0) },
            onReschedule: { reschedulingTask = $0 },
            onAutoSortAll: { runAutoSortAnytime() },
            onEditTask: { editingTask = $0 },
            onDeleteTask: { deletingTask = $0 },
            onAdd: { openComposer() }
        )
    }

    private var dayTimeline: some View {
        DayTimelineView(
            entries: timeline.timed,
            classifyingEventIDs: classifyingEventIDs,
            routineRow: { routineRow(group: $0, tasks: $1) },
            onPickEnergy: { item, level in applyEnergy(item, level: level) },
            onAutoClassify: { autoClassifyOne($0) },
            onReschedule: { reschedulingTask = $0 },
            onEditTask: { editingTask = $0 },
            onDeleteTask: { deletingTask = $0 }
        )
    }

    // MARK: - Routine rows

    /// A single routine group card for the timeline, placed at its reminder time.
    private func routineRow(group: RoutineGroup, tasks: [Task]) -> AnyView {
        let isToday = calendar.isDate(selectedDate, inSameDayAs: Date())
        return AnyView(
            RoutineSlotSection(
                group: group,
                tasks: tasks,
                onToggle: { toggleRoutine($0) },
                onEdit: { presentRoutineEdit(for: $0) },
                onDelete: { deletingRoutineTask = $0 },
                onAddItem: { addingInGroup = $0 },
                onEditGroup: { editingGroup = $0 },
                onDeleteGroup: { deletingGroup = $0 },
                isPreview: !isToday,
                onStartRun: { store.startRoutineRun(group: $0, tasks: tasks, context: modelContext) },
                onResumeRun: { store.resumeRoutineRun(group: $0, tasks: tasks, context: modelContext) },
                isPausedRun: store.isPaused(group: group),
                runDisabled: store.activeTask != nil
            )
        )
    }

    /// Single entry point to create a routine group (the slot headers that used
    /// to host per-slot "New group" buttons are gone).
    private var newRoutineGroupButton: some View {
        Menu {
            ForEach(RoutineSlot.allCases) { slot in
                Button {
                    addingGroupSlot = slot
                } label: {
                    Text(slotLabel(slot))
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 13, weight: .semibold))
                Text("New routine group")
                    .font(AppFont.caption)
                Spacer()
            }
            .foregroundStyle(palette.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(palette.border)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Add a new routine group")
    }

    // MARK: - Routine actions (mirrors TaskListView)

    private func toggleRoutine(_ task: Task) {
        if !task.isCompleted { store.impactHaptic(.light) }
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? Date() : nil
        task.markDirty()
        modelContext.saveAndSync()
    }

    private func presentRoutineEdit(for task: Task) {
        guard let rid = task.sourceRoutineID,
              let tag = everyRoutine.first(where: { $0.id == rid }) else { return }
        editingRoutine = tag
    }

    private func todayInstance(of routine: RoutineTag) -> Task? {
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return allTasks.first { t in
            t.sourceRoutineID == routine.id
                && (t.scheduledDate.map { $0 >= start && $0 < end } ?? false)
        }
    }

    private func performGroupDelete(_ group: RoutineGroup) {
        let tagsInGroup = everyRoutine.filter { $0.groupID == group.id }
        let tagIDs = Set(tagsInGroup.map(\.id))
        let derived = allTasks.filter { $0.sourceRoutineID.map { tagIDs.contains($0) } ?? false }
        for t in derived {
            SyncEngine.shared.deleteRemote(Task.self, id: t.id)
            modelContext.delete(t)
        }
        for tag in tagsInGroup { modelContext.delete(tag) }
        modelContext.delete(group)
        modelContext.saveAndSync()
        NotificationManager.refreshAllRoutineReminders(context: modelContext)
    }

    private func slotLabel(_ slot: RoutineSlot) -> String {
        switch slot {
        case .morning:   return "Morning"
        case .afternoon: return "Afternoon"
        case .evening:   return "Evening"
        }
    }

    /// Calendar-tab delete for a regular Task (not a routine). Mirrors the
    /// home tab's path: detach any running timer, drop parked rows, delete
    /// locally, then fire-and-forget delete on Supabase.
    private func performTaskDelete(_ task: Task) {
        if store.activeTask?.id == task.id {
            store.timerRunning = false
            store.activeTask = nil
            store.stopTicker()
            NotificationManager.cancelCompletion()
            LiveActivityController.end()
        }
        SyncEngine.shared.deleteRemote(Task.self, id: task.id)
        modelContext.delete(task)
        modelContext.saveAndSync()
    }

    private func performRoutineDelete(_ task: Task) {
        guard let rid = task.sourceRoutineID else {
            modelContext.delete(task)
            modelContext.saveAndSync()
            return
        }
        let derived = allTasks.filter { $0.sourceRoutineID == rid }
        for t in derived {
            SyncEngine.shared.deleteRemote(Task.self, id: t.id)
            modelContext.delete(t)
        }
        if let tag = everyRoutine.first(where: { $0.id == rid }) {
            modelContext.delete(tag)
        }
        modelContext.saveAndSync()
        NotificationManager.refreshAllRoutineReminders(context: modelContext)
    }

    // MARK: - Actions

    private func applyEnergy(_ item: DayItem, level: EnergyLevel) {
        switch item {
        case .event(let event):
            event.energy = level
            event.userOverrideEnergy = true
        case .task(let task, _):
            guard EnergyLevel.taskAssignable.contains(level) else { return }
            task.energyTag = level
        }
        modelContext.saveAndSync()
    }

    private func autoClassifyOne(_ item: DayItem) {
        guard case .event(let event) = item else { return }
        let eventID = event.id
        event.userOverrideEnergy = false
        modelContext.saveAndSync()
        classifyingEventIDs.insert(eventID)
        _Concurrency.Task {
            await EventEnergyClassifier.classify(events: [event], in: modelContext)
            await MainActor.run {
                // `_ =` so the closure's implicit return type is Void rather
                // than `Set.Element?`, which would trigger an "unused result"
                // warning at the await site.
                _ = classifyingEventIDs.remove(eventID)
            }
        }
    }

    private func runAutoSortAnytime() {
        let anytimeItems = timeline.noSetTime
        guard !anytimeItems.isEmpty, !isAutoSortingAnytime else { return }
        let eventIDs = Set(anytimeItems.compactMap { item -> UUID? in
            if case .event(let e) = item { return e.id }
            return nil
        })
        isAutoSortingAnytime = true
        classifyingEventIDs.formUnion(eventIDs)
        let day = selectedDate
        _Concurrency.Task {
            await AnytimeAutoSorter.sort(items: anytimeItems, on: day, in: modelContext)
            await MainActor.run {
                isAutoSortingAnytime = false
                classifyingEventIDs.subtract(eventIDs)
            }
        }
    }

    private func runAutoSort() {
        let toClassify = dayItems.compactMap { item -> ImportedEvent? in
            if case .event(let e) = item, !e.userOverrideEnergy { return e }
            return nil
        }
        guard !toClassify.isEmpty else { return }
        classifyInFlight = true
        let ids = Set(toClassify.map(\.id))
        classifyingEventIDs.formUnion(ids)
        _Concurrency.Task {
            await EventEnergyClassifier.classify(events: toClassify, in: modelContext)
            await MainActor.run {
                classifyInFlight = false
                classifyingEventIDs.subtract(ids)
            }
        }
    }

    private func runCalendarImport() {
        importInFlight = true
        _Concurrency.Task {
            do {
                _ = try await CalendarImportService.importNext14Days(into: modelContext)
                await MainActor.run {
                    store.calendarImported = true
                    store.tipImportCalendarDismissed = true
                    importInFlight = false
                }
            } catch CalendarImportService.ImportError.denied {
                Analytics.track(.calendarImportFailed(reason: "denied"))
                AnalyticsErrorReporter.reportMessage("calendar denied", context: "calendar.import.denied", level: "warning")
                await MainActor.run {
                    importInFlight = false
                    importError = "Calendar access was denied. You can enable it in Settings."
                }
            } catch {
                Analytics.track(.calendarImportFailed(reason: "other"))
                AnalyticsErrorReporter.report(error, context: "calendar.import.other")
                await MainActor.run {
                    importInFlight = false
                    importError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Day timeline
//
// Lives in this file (rather than its own) because Xcode's synchronized-folder
// file watching is unreliable on this mounted volume — a standalone file added
// externally wasn't reliably picked up into the target.

/// Vertical day timeline for the Schedule tab. Groups timed entries (events,
/// task occurrences, routine groups) under a sparse hour rail — only hours that
/// actually have something are shown. Replaces the fixed MORNING/AFTERNOON/
/// EVENING period buckets with a chronological, clock-driven layout.
struct DayTimelineView: View {
    let entries: [TimelineEntry]
    let classifyingEventIDs: Set<UUID>
    /// Builds the RoutineSlotSection card for a routine group entry.
    let routineRow: (RoutineGroup, [Task]) -> AnyView
    let onPickEnergy: (DayItem, EnergyLevel) -> Void
    let onAutoClassify: (DayItem) -> Void
    var onReschedule: ((Task) -> Void)? = nil
    var onEditTask: ((Task) -> Void)? = nil
    var onDeleteTask: ((Task) -> Void)? = nil

    @Environment(\.palette) private var palette
    private let calendar = Calendar.current

    /// One hour band of the timeline. A concrete Identifiable type (rather than
    /// a labeled tuple) keeps the SwiftUI `body` cheap to type-check.
    private struct HourGroup: Identifiable {
        let hour: Int
        let entries: [TimelineEntry]
        var id: Int { hour }
    }

    private var hourGroups: [HourGroup] {
        let grouped: [Int: [TimelineEntry]] = Dictionary(grouping: entries) { $0.hour }
        let hours: [Int] = grouped.keys.sorted()
        return hours.map { hour in
            HourGroup(hour: hour, entries: grouped[hour] ?? [])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(hourGroups) { group in
                hourRow(group)
            }
        }
    }

    private func hourRow(_ group: HourGroup) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 6) {
                Text(hourLabel(group.hour))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)
                Rectangle()
                    .fill(palette.border)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 52)

            VStack(spacing: 8) {
                ForEach(group.entries) { entry in
                    entryView(entry)
                }
            }
        }
    }

    @ViewBuilder
    private func entryView(_ entry: TimelineEntry) -> some View {
        switch entry {
        case .item(let item):
            DayItemCard(
                item: item,
                isClassifying: isClassifying(item),
                onPickEnergy: { onPickEnergy(item, $0) },
                onAutoClassify: { onAutoClassify(item) },
                onReschedule: onReschedule,
                onEditTask: onEditTask,
                onDeleteTask: onDeleteTask
            )
        case .routine(let group, let tasks, _):
            routineRow(group, tasks)
        }
    }

    private func isClassifying(_ item: DayItem) -> Bool {
        if case .event(let event) = item {
            return classifyingEventIDs.contains(event.id)
        }
        return false
    }

    private func hourLabel(_ hour: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        let date = calendar.date(from: comps) ?? Date()
        let f = DateFormatter()
        f.dateFormat = "h a"
        return f.string(from: date)
    }
}
