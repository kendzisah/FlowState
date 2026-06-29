import SwiftUI

enum HomeTab: Int, Hashable, CaseIterable {
    case tasks, calendar, chat
}

struct HomeTabView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var bindable = store

        TabView(selection: $bindable.homeTab) {
            TaskListView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
                .tag(HomeTab.tasks)

            CalendarTabView()
                .tabItem {
                    Label("Schedule", systemImage: calendarIconName)
                }
                .tag(HomeTab.calendar)

            ChatTabView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.fill")
                }
                .tag(HomeTab.chat)
        }
        .tint(palette.textPrimary)
    }

    /// Day-of-month icon (`1.square` ... `31.square`). Falls back to `calendar` if the
    /// SF Symbol for today's day isn't available.
    private var calendarIconName: String {
        let day = Calendar.current.component(.day, from: Date())
        return "\(day).square"
    }
}
