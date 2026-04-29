import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context

    @Query(sort: \Task.createdAt, order: .reverse) private var allTasks: [Task]
    @Query(sort: \ParkedTask.parkedAt, order: .reverse) private var parkedTasks: [ParkedTask]

    @State private var selectedTab: TaskListTab = .tasks
    @Namespace private var taskCardNS

    var body: some View {
        @Bindable var bindable = store

        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                header
                content
            }
            BottomTabBar(selected: $selectedTab, parkedCount: parkedTasks.count)
        }
        .sheet(isPresented: $bindable.showAddTask) {
            AddTaskSheet()
                .environment(\.palette, palette)
        }
        .sheet(isPresented: $bindable.showSettings) {
            SettingsSheet()
                .environment(\.palette, palette)
        }
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
                if let energy = store.energyLevel,
                   energy != .foggy,
                   store.matchingCount(allTasks) > 0 {
                    MatchBanner(count: store.matchingCount(allTasks), level: energy)
                        .padding(.bottom, 4)
                }

                ForEach(store.sortedTasks(allTasks), id: \.id) { task in
                    let parked = parkedTasks.first(where: { $0.taskId == task.id })
                    let isMatching = isCardMatching(task)
                    TaskCard(
                        task: task,
                        parked: parked,
                        isMatching: isMatching,
                        namespace: taskCardNS
                    ) {
                        if let parked {
                            store.resumeParked(parked, allTasks: allTasks, context: context)
                        } else {
                            store.startTask(task)
                        }
                    }
                }

                if allTasks.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, Geometry.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
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
