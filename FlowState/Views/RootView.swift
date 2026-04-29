import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var systemColorScheme

    private enum Route {
        case onboarding, paywall, timer, checkin, rest, tasks
    }

    private var route: Route {
        if !store.hasCompletedOnboarding { return .onboarding }

        let foggyRestAccessible = store.energyIsActiveToday
            && store.energyLevel == .foggy
            && !store.peekList

        if !store.entitled && !foggyRestAccessible { return .paywall }

        if store.timerRunning || store.activeTask != nil { return .timer }
        if !store.energyIsActiveToday                    { return .checkin }
        if store.energyLevel == .foggy && !store.peekList { return .rest }
        return .tasks
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
                case .onboarding: OnboardingView()
                case .paywall:    PaywallView { store.entitled = true }
                case .timer:      TimerView()
                case .checkin:    CheckInView()
                case .rest:       RestView()
                case .tasks:      TaskListView()
                }
            }
            .environment(\.palette, palette)

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
