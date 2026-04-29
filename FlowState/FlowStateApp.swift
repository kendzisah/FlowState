import SwiftUI
import SwiftData

@main
struct FlowStateApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: Task.self, ParkedTask.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .modelContainer(modelContainer)
                .onChange(of: scenePhase) { _, newPhase in
                    store.handleScenePhase(newPhase)
                }
        }
    }
}
