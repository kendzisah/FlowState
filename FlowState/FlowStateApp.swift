import SwiftUI
import SwiftData
import UserNotifications

@main
struct FlowStateApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: Task.self, ParkedTask.self, RoutineTag.self, RoutineGroup.self, ImportedEvent.self)
        } catch {
            // Best-effort capture before crashing so the failure shows up in
            // PostHog Errors. The flush is synchronous and gets a 0.5s window
            // — not perfect, but better than the prior unobservable fatal.
            AnalyticsErrorReporter.reportMessage(
                String(describing: error),
                context: "app.modelContainer",
                level: "fatal"
            )
            PostHogProvider.shared.flushSync()
            Thread.sleep(forTimeInterval: 0.5)
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    init() {
        SubscriptionManager.shared.configure()
        // Analytics needs to be up before SubscriptionManager.bind so we can
        // observe the first entitlement emission.
        AnalyticsManager.shared.configure()
        // Wire the notification tap delegate at process start so taps that
        // launch the app cold still route correctly.
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .modelContainer(modelContainer)
                .task {
                    // Expose the store for non-View widget-refresh callers
                    // (ModelContext+Sync, etc.) without prop-drilling.
                    AppStore.activeInstanceForWidgetRefresh = store

                    SubscriptionManager.shared.bind(to: store)
                    await AuthManager.shared.restore()

                    // Fire app_launched after restore so we know whether
                    // there's a session and an entitlement at launch time.
                    Analytics.track(.appLaunched(
                        cold: true,
                        hasSession: AuthManager.shared.isAuthenticated,
                        entitled: store.entitled,
                        appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
                        build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
                    ))

                    // If user is already signed-in (returning install), identify now.
                    if let uid = AuthManager.shared.currentUserID {
                        Analytics.identify(userID: uid, traits: store.analyticsTraits())
                    }

                    // Drain any widget-triggered actions queued while the app
                    // was killed.
                    drainPendingWidgetActions()

                    // Initial widget snapshot so home-screen widgets render
                    // current state on first launch.
                    WidgetSnapshotWriter.refresh(store: store, context: modelContainer.mainContext)
                    // Rebuild notification slots. Idempotent — also runs
                    // every foreground in case iOS pruned anything.
                    NotificationManager.refreshAllRoutineReminders(context: modelContainer.mainContext)
                    NotificationManager.refreshAllTaskReminders(context: modelContainer.mainContext)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    store.handleScenePhase(newPhase)
                    if newPhase == .active {
                        drainPendingWidgetActions()
                        WidgetSnapshotWriter.refresh(store: store, context: modelContainer.mainContext)
                        NotificationManager.refreshAllRoutineReminders(context: modelContainer.mainContext)
                        NotificationManager.refreshAllTaskReminders(context: modelContainer.mainContext)
                    }
                }
                .onOpenURL { url in
                    let allTasks = (try? modelContainer.mainContext.fetch(FetchDescriptor<Task>())) ?? []
                    DeepLinkRouter.handle(
                        url,
                        store: store,
                        context: modelContainer.mainContext,
                        allTasks: allTasks
                    )
                }
        }
    }

    private func drainPendingWidgetActions() {
        let allTasks = (try? modelContainer.mainContext.fetch(FetchDescriptor<Task>())) ?? []
        DeepLinkRouter.drainPendingActions(
            store: store,
            context: modelContainer.mainContext,
            allTasks: allTasks
        )
    }
}
