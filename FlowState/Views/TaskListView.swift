import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context

    @Query(sort: \Task.createdAt, order: .reverse) private var everyTask: [Task]
    @Query(sort: \ParkedTask.parkedAt, order: .reverse) private var everyParked: [ParkedTask]
    @Query(sort: \ImportedEvent.startDate) private var everyEvent: [ImportedEvent]

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
    private var allEvents: [ImportedEvent] {
        guard let uid = AuthManager.shared.currentUserID else { return [] }
        return everyEvent.filter { $0.userID == uid }
    }

    @State private var selectedTab: TaskListTab = .tasks
    @State private var schedulingTask: Task?
    @State private var editingTask: Task?
    @State private var deletingTask: Task?
    @Namespace private var taskCardNS

    /// Tasks worth surfacing today: unscheduled (backlog) + scheduled for today
    /// or earlier (so past-due items roll forward). Future-scheduled tasks are
    /// hidden until their day arrives — they live on the Calendar tab.
    /// Routine tasks are excluded entirely; routines are created and managed on
    /// the Calendar tab, not here.
    private var todayTasks: [Task] {
        let calendar = Calendar.current
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        return allTasks.filter { task in
            if task.isRoutine { return false }
            guard let scheduled = task.scheduledDate else { return true }
            return scheduled < endOfToday
        }
    }

    /// Flexible work — no committed clock time. These flow into the energy
    /// lanes and are surfaced by current energy. (Anchored tasks are pulled
    /// out into the FixedPointsRail instead.)
    private var flexibleToday: [Task] {
        todayTasks.filter { !$0.isAnchored }
    }

    /// Anchored items for today, time-sorted: imported calendar events plus
    /// tasks the user committed to a clock time. Rendered in the FixedPointsRail
    /// above the energy lanes.
    private var anchoredToday: [DayItem] {
        let calendar = Calendar.current
        let today = Date()
        var items: [DayItem] = []

        for event in allEvents where CalendarDayBuckets.event(event, overlaps: today, calendar: calendar) {
            items.append(.event(event))
        }

        for task in todayTasks where task.isAnchored && !task.isCompleted {
            // Recurring tasks only appear on days their rule fires. Non-recurring
            // tasks fall back to their original time so a past-due appointment
            // that rolled forward into today still shows.
            let when: Date? = task.recurrence == .none
                ? (task.occurrenceDate(on: today, calendar: calendar) ?? task.scheduledDate)
                : task.occurrenceDate(on: today, calendar: calendar)
            if let when {
                items.append(.task(task, occurrenceDate: when))
            }
        }
        return items
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Spacer()
                iconButton(systemName: "gearshape", label: "Settings") {
                    store.showSettings = true
                }
                iconButton(systemName: "plus", label: "Add task") {
                    store.showAddTask = true
                }
            }
            EnergyHero()
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
                // Fixed commitments are time-bound facts the user still needs
                // even when foggy, so the rail shows regardless of energy.
                FixedPointsRail(items: anchoredToday) { task in
                    editingTask = task
                }

                // Foggy hides the energy-matched task list entirely — rest is
                // a legitimate state and the system shouldn't pile a backlog
                // on top of someone trying to rest.
                if store.energyLevel != .foggy {
                    energySections
                }

                if anchoredToday.isEmpty && flexibleToday.isEmpty {
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
                let tasksAtLevel = flexibleToday
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
        .animation(.easeOut(duration: 0.3), value: flexibleToday.filter { !$0.isCompleted }.map(\.id))
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
            Text("Nothing on the list.")
                .font(AppFont.body)
                .foregroundStyle(palette.textSecondary)
            Text("Tap + when something needs doing.")
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
