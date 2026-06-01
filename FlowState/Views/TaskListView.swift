import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context

    @Query(sort: \Task.createdAt, order: .reverse) private var everyTask: [Task]
    @Query(sort: \ParkedTask.parkedAt, order: .reverse) private var everyParked: [ParkedTask]

    /// Rows owned by the signed-in user. SwiftData stores everyone's data
    /// locally; the filter (plus Supabase RLS) is what scopes display.
    private var allTasks: [Task] {
        guard let uid = AuthManager.shared.currentUserID else { return [] }
        return everyTask.filter { $0.userID == uid }
    }
    private var parkedTasks: [ParkedTask] {
        guard let uid = AuthManager.shared.currentUserID else { return [] }
        return everyParked.filter { $0.userID == uid }
    }

    @State private var selectedTab: TaskListTab = .tasks
    @State private var schedulingTask: Task?
    @State private var editingTask: Task?
    @State private var deletingTask: Task?
    @State private var editingRoutine: RoutineTag?
    @State private var deletingRoutineTask: Task?
    @State private var addingInGroup: RoutineGroup?
    @State private var addingGroupSlot: RoutineSlot?
    @State private var editingGroup: RoutineGroup?
    @State private var deletingGroup: RoutineGroup?
    @Namespace private var taskCardNS

    @Query private var everyRoutine: [RoutineTag]
    @Query private var everyGroup: [RoutineGroup]

    private var allGroups: [RoutineGroup] {
        guard let uid = AuthManager.shared.currentUserID else { return [] }
        return everyGroup.filter { $0.userID == uid || $0.userID == nil }
    }

    /// Tasks worth surfacing today: unscheduled (backlog) + scheduled for today
    /// or earlier (so past-due items roll forward). Future-scheduled tasks are
    /// hidden until their day arrives — they live on the Calendar tab.
    /// Routine tasks are excluded; they render in their own slot groups above
    /// via `routinesBySlot`.
    private var todayTasks: [Task] {
        let calendar = Calendar.current
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        return allTasks.filter { task in
            if task.isRoutine { return false }
            guard let scheduled = task.scheduledDate else { return true }
            return scheduled < endOfToday
        }
    }

    /// Today's routine groups, organized by slot. Each entry pairs a group
    /// with the materialized child tasks for today. Includes completed tasks
    /// so the `X/Y` progress counter reflects the user's actual day-state.
    /// Empty groups (no children today) are kept so users can still
    /// long-press the header to add items or delete the group.
    private func groupsByGroupID(for today: [Task]) -> [UUID: [Task]] {
        var byGroup: [UUID: [Task]] = [:]
        for t in today {
            guard let rid = t.sourceRoutineID,
                  let tag = everyRoutine.first(where: { $0.id == rid }),
                  let gid = tag.groupID else { continue }
            byGroup[gid, default: []].append(t)
        }
        return byGroup
    }

    private var groupsForToday: [(slot: RoutineSlot, group: RoutineGroup, tasks: [Task])] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? Date()
        let today = allTasks.filter { task in
            guard task.isRoutine, let s = task.scheduledDate else { return false }
            return s >= startOfToday && s < endOfToday
        }
        let byGroup = groupsByGroupID(for: today)

        let slotOrder: [RoutineSlot] = [.morning, .afternoon, .evening]
        var result: [(slot: RoutineSlot, group: RoutineGroup, tasks: [Task])] = []
        for slot in slotOrder {
            let groupsInSlot = allGroups
                .filter { $0.slot == slot
                    && $0.recurrence.coversToday(from: $0.createdAt, calendar: calendar) }
                .sorted { $0.createdAt < $1.createdAt }
            for g in groupsInSlot {
                let tasks = (byGroup[g.id] ?? [])
                    .sorted { ($0.scheduledDate ?? .distantPast) < ($1.scheduledDate ?? .distantPast) }
                // Hide a group once every routine for today is complete — the
                // user is "done" with it for today. Empty groups (no children
                // yet) still show so the user can add routines or manage it.
                let allDone = !tasks.isEmpty && tasks.allSatisfy(\.isCompleted)
                if allDone { continue }
                result.append((slot, g, tasks))
            }
        }
        return result
    }

    var body: some View {
        @Bindable var bindable = store

        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                header
                content
            }
            BottomTabBar(selected: $selectedTab, parkedCount: parkedTasks.count)
        }
        .firstTimeTooltip(
            id: "home.tasks",
            title: "Your day, sorted by energy",
            body: "Tap + to add a task. Swipe a card to schedule, park, edit, or delete it. Tasks match the energy level you're in right now."
        )
        .sheet(isPresented: $bindable.showAddTask) {
            AddTaskSheet()
                .environment(\.palette, palette)
        }
        .sheet(isPresented: $bindable.showSettings) {
            SettingsSheet()
                .environment(\.palette, palette)
        }
        .sheet(item: $schedulingTask) { task in
            ScheduleTaskSheet(task: task) {
                schedulingTask = nil
            }
            .environment(\.palette, palette)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingTask) { task in
            AddTaskSheet(editing: task)
                .environment(\.palette, palette)
        }
        .sheet(item: $editingRoutine) { routine in
            EditRoutineSheet(routine: routine, materializedToday: todayInstance(of: routine))
                .environment(\.palette, palette)
        }
        .sheet(item: $addingInGroup) { group in
            EditRoutineSheet(defaultGroup: group)
                .environment(\.palette, palette)
        }
        .sheet(item: $addingGroupSlot) { slot in
            EditRoutineGroupSheet(defaultSlot: slot)
                .environment(\.palette, palette)
        }
        .sheet(item: $editingGroup) { group in
            EditRoutineGroupSheet(group: group)
                .environment(\.palette, palette)
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
        .alert(
            "Delete task?",
            isPresented: Binding(
                get: { deletingTask != nil },
                set: { if !$0 { deletingTask = nil } }
            ),
            presenting: deletingTask
        ) { task in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { performDelete(task) }
        } message: { task in
            Text("\u{201C}\(task.title)\u{201D} will be removed. This can't be undone.")
        }
    }

    /// Quick checkbox completion for routine rows. No timer involved —
    /// the routine just marks itself done for today. `RoutineScheduler` will
    /// materialize a fresh instance tomorrow. A light haptic acknowledges
    /// the tap; the row fades out via `RoutineSlotSection`'s transition.
    private func toggleRoutine(_ task: Task) {
        if !task.isCompleted { store.impactHaptic(.light) }
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? Date() : nil
        task.markDirty()
        context.saveAndSync()
    }

    private func presentRoutineEdit(for task: Task) {
        guard let rid = task.sourceRoutineID,
              let tag = everyRoutine.first(where: { $0.id == rid }) else { return }
        editingRoutine = tag
    }

    private func todayInstance(of routine: RoutineTag) -> Task? {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? Date()
        return allTasks.first { t in
            t.sourceRoutineID == routine.id
                && (t.scheduledDate.map { $0 >= start && $0 < end } ?? false)
        }
    }

    /// Deletes a whole `RoutineGroup` plus every child tag and every Task
    /// ever materialized from those tags. Fire-and-forget remote delete so
    /// the server doesn't resurrect them on the next pull.
    private func performGroupDelete(_ group: RoutineGroup) {
        let tagsInGroup = everyRoutine.filter { $0.groupID == group.id }
        let tagIDs = Set(tagsInGroup.map(\.id))
        let derived = allTasks.filter { $0.sourceRoutineID.map { tagIDs.contains($0) } ?? false }
        for t in derived {
            SyncEngine.shared.deleteRemote(Task.self, id: t.id)
            context.delete(t)
        }
        for tag in tagsInGroup { context.delete(tag) }
        context.delete(group)
        context.saveAndSync()
        NotificationManager.refreshAllRoutineReminders(context: context)
    }

    @ViewBuilder
    private var routineSections: some View {
        let entries = groupsForToday
        let slotOrder: [RoutineSlot] = [.morning, .afternoon, .evening]
        VStack(spacing: 12) {
            ForEach(slotOrder, id: \.self) { slot in
                let slotEntries = entries.filter { $0.slot == slot }
                ForEach(slotEntries, id: \.group.id) { entry in
                    RoutineSlotSection(
                        group: entry.group,
                        tasks: entry.tasks,
                        onToggle: { toggleRoutine($0) },
                        onEdit: { presentRoutineEdit(for: $0) },
                        onDelete: { deletingRoutineTask = $0 },
                        onAddItem: { addingInGroup = $0 },
                        onEditGroup: { editingGroup = $0 },
                        onDeleteGroup: { deletingGroup = $0 }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                }
            }
            newRoutineGroupButton
        }
        .animation(.easeOut(duration: 0.3), value: entries.map(\.group.id))
    }

    /// One general entry-point for creating a routine group. The sheet itself
    /// asks for a reminder time and auto-derives the slot, so we no longer
    /// need three slot-specific buttons.
    private var newRoutineGroupButton: some View {
        Button {
            addingGroupSlot = RoutineSlot.from(hour: Calendar.current.component(.hour, from: Date()))
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
        .accessibilityLabel("New routine group")
    }

    /// Deletes the source routine (so it stops repeating) and every Task
    /// already materialized from it. We also fire `deleteRemote` for each
    /// task so Supabase doesn't resurrect them on the next pull.
    private func performRoutineDelete(_ task: Task) {
        guard let rid = task.sourceRoutineID else {
            context.delete(task)
            context.saveAndSync()
            return
        }
        let derived = allTasks.filter { $0.sourceRoutineID == rid }
        for t in derived {
            SyncEngine.shared.deleteRemote(Task.self, id: t.id)
            context.delete(t)
        }
        if let tag = everyRoutine.first(where: { $0.id == rid }) {
            context.delete(tag)
        }
        context.saveAndSync()
        NotificationManager.refreshAllRoutineReminders(context: context)
    }

    private func performDelete(_ task: Task) {
        if store.activeTask?.id == task.id {
            store.timerRunning = false
            store.activeTask = nil
            store.stopTicker()
            NotificationManager.cancelCompletion()
            LiveActivityController.end()
        }
        for parked in parkedTasks where parked.taskId == task.id {
            context.delete(parked)
        }
        context.delete(task)
        context.saveAndSync()
    }

    private var header: some View {
        HStack(spacing: 8) {
            BatteryPill()
            Spacer()
            iconButton(systemName: "gearshape", label: "Settings") {
                store.showSettings = true
            }
            iconButton(systemName: "plus", label: "Add task") {
                store.showAddTask = true
            }
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func iconButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(palette.textPrimary)
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(palette.surface)
                        .overlay(Circle().stroke(palette.border, lineWidth: 1))
                )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var content: some View {
        if selectedTab == .tasks {
            tasksContent
        } else {
            ParkedTabView(parkedTasks: parkedTasks, allTasks: allTasks)
        }
    }

    private var tasksContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                routineSections

                // Foggy hides the energy-matched task list entirely — rest is
                // a legitimate state and the system shouldn't pile a backlog
                // on top of someone trying to rest. Routines (energy-neutral)
                // remain because they're habit anchors, not work.
                if store.energyLevel != .foggy {
                    energySections
                }

                if todayTasks.isEmpty && groupsForToday.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, Geometry.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    @ViewBuilder
    private var energySections: some View {
        let currentEnergy = store.energyLevel
        VStack(spacing: 12) {
            ForEach(EnergyLevel.taskAssignable, id: \.self) { level in
                let tasksAtLevel = todayTasks
                    .filter { !$0.isCompleted && $0.energyTag == level }
                    .sorted { $0.createdAt > $1.createdAt }
                if !tasksAtLevel.isEmpty {
                    let isMatching = currentEnergy == level
                    EnergyTaskSection(
                        level: level,
                        count: tasksAtLevel.count,
                        isMatching: isMatching,
                        defaultExpanded: isMatching
                    ) {
                        ForEach(tasksAtLevel, id: \.id) { task in
                            taskCardFor(task)
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .scale(scale: 0.95).combined(with: .opacity)
                                ))
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: todayTasks.filter { !$0.isCompleted }.map(\.id))
    }

    @ViewBuilder
    private func taskCardFor(_ task: Task) -> some View {
        let parked = parkedTasks.first(where: { $0.taskId == task.id })
        let isMatching = isCardMatching(task)
        TaskCard(
            task: task,
            parked: parked,
            isMatching: isMatching,
            namespace: taskCardNS,
            onPrimary: {
                if let parked {
                    store.resumeParked(parked, allTasks: allTasks, context: context)
                } else {
                    store.startTask(task)
                }
            },
            onSchedule: { schedulingTask = task },
            onUnschedule: {
                task.scheduledDate = nil
                context.saveAndSync()
            },
            onEdit: { editingTask = task },
            onDelete: { deletingTask = task }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Nothing here yet.")
                .font(AppFont.body)
                .foregroundStyle(palette.textSecondary)
            Text("Tap + to add your first task.")
                .font(AppFont.caption)
                .foregroundStyle(palette.textDimmed)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func isCardMatching(_ task: Task) -> Bool {
        guard let energy = store.energyLevel, energy != .foggy else { return true }
        return task.energyTag == energy
    }
}
