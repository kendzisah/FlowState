import SwiftUI
import StoreKit
import SwiftData

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    @State private var lastForegroundedAt: Date?
    @State private var lastScreenName: String?

    private var auth: AuthManager { .shared }

    private enum Route {
        case splash, onboarding, paywall, timer, checkin, rest, home
    }

    private var route: Route {
        // While AuthManager is still pulling the session out of the Keychain,
        // hold a splash so we don't briefly flash the welcome screen to a
        // returning user.
        if auth.isRestoring { return .splash }

        // Account is mandatory. Even if `hasCompletedOnboarding` is true
        // (e.g., a returning user whose Keychain got wiped), they have to
        // sign back in before they can use the app.
        if !auth.isAuthenticated { return .onboarding }

        if !store.hasCompletedOnboarding { return .onboarding }

        let foggyRestAccessible = store.energyIsActiveToday
            && store.energyLevel == .foggy
            && !store.peekList

        if !store.entitled && !foggyRestAccessible { return .paywall }

        if store.timerRunning || store.activeTask != nil { return .timer }
        if !store.energyIsActiveToday                    { return .checkin }
        if store.energyLevel == .foggy && !store.peekList { return .rest }
        return .home
    }

    private var palette: Palette {
        Palette.resolve(store.themeMode, system: systemColorScheme)
    }

    var body: some View {
        @Bindable var bindable = store

        ZStack {
            BackgroundLayer()
                .environment(\.palette, palette)

            Group {
                switch route {
                case .splash:     LaunchSplash()
                case .onboarding: OnboardingCoordinator()
                case .paywall:    PaywallView { _ in store.entitled = true }
                case .timer:      TimerView()
                case .checkin:    CheckInView()
                case .rest:       RestView()
                case .home:       HomeTabView()
                }
            }
            .environment(\.palette, palette)
            .onChange(of: route) { _, newRoute in
                handleRouteChange(newRoute)
            }
            .onAppear { handleRouteChange(route) }

            if let dialog = store.completionDialog {
                CompletionDialog(state: dialog) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        store.completionDialog = nil
                    }
                }
                .environment(\.palette, palette)
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .preferredColorScheme(store.themeMode.preferred)
        .sheet(isPresented: $bindable.showEnergySwitcher) {
            EnergySwitcherSheet()
                .environment(\.palette, palette)
        }
        .task(id: auth.currentUserID) {
            // Fires on cold-launch (after restore) and on every sign-in/out.
            // When the user signs in (or restores a session), claim any orphan
            // rows and run a full sync. Sign-out leaves local data on disk.
            guard auth.currentUserID != nil else { return }
            RoutineScheduler.materializeToday(context: modelContext, userID: auth.currentUserID)
            await SyncEngine.shared.runFullSync(context: modelContext)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                let hoursSince = lastForegroundedAt.map { Date().timeIntervalSince($0) / 3600 } ?? 0
                Analytics.track(.appForegrounded(hoursSinceLastActive: hoursSince))
                lastForegroundedAt = Date()
            } else if newPhase == .background && oldPhase != .background {
                Analytics.track(.appBackgrounded)
            }
            guard newPhase == .active, auth.isAuthenticated else { return }
            RoutineScheduler.materializeToday(context: modelContext, userID: auth.currentUserID)
            ReviewPromptManager.recordAppForeground(store: store)
            _Concurrency.Task {
                await SyncEngine.shared.runFullSync(context: modelContext)
            }
        }
        .onChange(of: store.pendingReviewRequest) { _, isPending in
            guard isPending else { return }
            Analytics.track(.reviewPromptShown)
            requestReview()
            ReviewPromptManager.markPromptShown()
            store.pendingReviewRequest = false
        }
        // Bridge notification taps (handled out-of-scene by `NotificationDelegate`)
        // into the same `DeepLinkRouter` that powers `.onOpenURL`. Keeps tap
        // routing identical to URL-scheme routing — one source of truth.
        .onReceive(NotificationCenter.default.publisher(for: .flowStateDeepLink)) { note in
            guard let url = note.object as? URL else { return }
            let allTasks = (try? modelContext.fetch(FetchDescriptor<Task>())) ?? []
            DeepLinkRouter.handle(url, store: store, context: modelContext, allTasks: allTasks)
        }
    }

    /// Centralised route-transition side-effects: fire `$screen` events and
    /// trigger the ATT prompt once the user reaches a post-onboarding route.
    /// Keeping this in one place means future routes only have to be added to
    /// the switch — they get analytics + ATT bookkeeping automatically.
    private func handleRouteChange(_ newRoute: Route) {
        let name: String
        switch newRoute {
        case .splash:     name = "Splash"
        case .onboarding: name = "Onboarding"
        case .paywall:    name = "Paywall"
        case .timer:      name = "Timer"
        case .checkin:    name = "CheckIn"
        case .rest:       name = "Rest"
        case .home:       name = "Home"
        }
        guard name != lastScreenName else { return }
        lastScreenName = name
        Analytics.screen(name)

        // ATT triggers when the user transitions out of splash/onboarding
        // into any "real" route. Onboarding is when they have the most
        // context for why we're asking, so grant rate is highest here.
        switch newRoute {
        case .paywall, .timer, .checkin, .rest, .home:
            _Concurrency.Task { @MainActor in await ATTManager.requestIfNeeded() }
        default:
            break
        }
    }
}

/// Shown briefly between cold-launch and AuthManager.restore() completing,
/// so a returning user doesn't see the welcome screen flash before the
/// session pulls out of Keychain.
private struct LaunchSplash: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(palette.parkedAccent)
                .scaleEffect(1.2)
            Text("FlowState")
                .font(AppFont.title)
                .tracking(AppFont.titleTracking)
                .foregroundStyle(palette.textPrimary)
                .opacity(0.85)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct BackgroundLayer: View {
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [palette.bgGradientStart, palette.bgGradientEnd],
                    startPoint: UnitPoint(x: 0.15, y: 0),
                    endPoint:   UnitPoint(x: 0.85, y: 1)
                )
                RadialGradient(
                    colors: [palette.bgRadialNW.opacity(0.6), .clear],
                    center: UnitPoint(x: 0.12, y: -0.10),
                    startRadius: 0,
                    endRadius: max(geo.size.width * 0.9, geo.size.height * 0.65)
                )
                .blendMode(.screen)
                RadialGradient(
                    colors: [palette.bgRadialSE.opacity(0.5), .clear],
                    center: UnitPoint(x: 1.05, y: 1.15),
                    startRadius: 0,
                    endRadius: max(geo.size.width * 0.85, geo.size.height * 0.75)
                )
                .blendMode(.screen)
            }
        }
        .ignoresSafeArea()
    }
}
