import SwiftUI
import SwiftData

@main
struct FlowStateApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: Task.self, ParkedTask.self, RoutineTag.self, RoutineGroup.self, ImportedEvent.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    init() {
        SubscriptionManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .modelContainer(modelContainer)
                .task {
                    SubscriptionManager.shared.bind(to: store)
                    await AuthManager.shared.restore()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    store.handleScenePhase(newPhase)
                }
        }
    }
}
