import SwiftUI
import SwiftData

enum OnboardingStep: Int, CaseIterable {
    case welcome = 1
    case marketingOptIn
    case biggestNeed
    case neurodivergence
    case socialProof
    case createAccount        // Hard auth gate — must succeed before paywall.
    case paywall
    case notifications
    case calendarImport
    case transitionReady
    case morningRoutines
    case afternoonRoutines
    case eveningRoutines
    case rating
    case transitionCapture
    case weeklyPlansInput
    case buildingTasks
    case pickTasks
    case finalCommit
    case tasksAdded

    static let total: Int = OnboardingStep.allCases.count

    /// Steps that show a skip link in the top-right.
    var isSkippable: Bool {
        switch self {
        case .notifications, .calendarImport, .rating: return true
        default: return false
        }
    }

    /// Steps with no chrome (no header/progress bar).
    var isFullBleed: Bool {
        switch self {
        case .welcome, .socialProof, .transitionReady,
             .transitionCapture, .buildingTasks, .tasksAdded, .finalCommit:
            return true
        default:
            return false
        }
    }

    /// Auto-advance after fixed delay. Nil means user must tap.
    var autoAdvanceSeconds: Double? {
        switch self {
        case .socialProof, .transitionReady, .transitionCapture, .tasksAdded: return 2.5
        default: return nil
        }
    }

    var showsBackArrow: Bool {
        switch self {
        case .welcome, .finalCommit: return false
        case .socialProof, .transitionReady, .transitionCapture,
             .buildingTasks, .tasksAdded:
            return false
        default:
            return true
        }
    }
}

struct OnboardingCoordinator: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext

    @State private var draft = OnboardingDraft()
    @State private var step: OnboardingStep = .welcome
    @State private var isCommitting = false

    var body: some View {
        ZStack(alignment: .top) {
            stepView(for: step)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))

            if !step.isFullBleed {
                OnbHeader(
                    progress: progress(for: step),
                    showBack: step.showsBackArrow,
                    showSkip: step.isSkippable,
                    onBack: goBack,
                    onSkip: advance
                )
            }
        }
        .onChange(of: step) { oldStep, newStep in
            scheduleAutoProgress(for: newStep)
            // `step_completed` fires for the leaving step so funnel
            // analysis sees a clean per-step transition pair.
            Analytics.track(.onboardingStepCompleted(step: oldStep.rawValue, name: String(describing: oldStep)))
            Analytics.track(.onboardingStepViewed(step: newStep.rawValue, name: String(describing: newStep)))
        }
        .onAppear {
            scheduleAutoProgress(for: step)
            if step == .welcome {
                Analytics.track(.onboardingStarted)
                Analytics.track(.onboardingStepViewed(step: step.rawValue, name: String(describing: step)))
            }
        }
    }

    @ViewBuilder
    private func stepView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:            Step01Welcome(draft: draft, onContinue: advance, onSkipOnboarding: skipToEnd)
        case .marketingOptIn:     Step02MarketingOptIn(draft: draft, onContinue: advance)
        case .biggestNeed:        Step03BiggestNeed(draft: draft, onContinue: advance)
        case .neurodivergence:    Step04Neurodivergence(draft: draft, onContinue: advance)
        case .socialProof:        Step05SocialProof()
        case .createAccount:      Step05bCreateAccount(draft: draft, onContinue: advance, onSkipOnboarding: skipToEnd)
        case .paywall:            Step06Paywall(draft: draft, onContinue: advance)
        case .notifications:      Step07Notifications(draft: draft, onContinue: advance)
        case .calendarImport:     Step08CalendarImport(draft: draft, onContinue: advance)
        case .transitionReady:    Step09TransitionReady()
        case .morningRoutines:    Step10MorningRoutines(draft: draft, onContinue: advance)
        case .afternoonRoutines:  Step11AfternoonRoutines(draft: draft, onContinue: advance)
        case .eveningRoutines:    Step12EveningRoutines(draft: draft, onContinue: advance)
        case .rating:             Step13Rating(onContinue: advance)
        case .transitionCapture:  Step14TransitionCapture()
        case .weeklyPlansInput:   Step15WeeklyPlansInput(draft: draft, onContinue: advance)
        case .buildingTasks:      Step16BuildingTasks(draft: draft, onContinue: advance)
        case .pickTasks:          Step17PickTasks(draft: draft, onContinue: advance)
        case .finalCommit:        Step19FinalCommit(draft: draft, onCommit: commit)
        case .tasksAdded:         Step18TasksAdded(draft: draft, onComplete: finishOnboarding)
        }
    }

    private func progress(for step: OnboardingStep) -> Double {
        Double(step.rawValue) / Double(OnboardingStep.total)
    }

    private func advance() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.28)) { step = next }
    }

    private func goBack() {
        guard let prev = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        withAnimation(.easeInOut(duration: 0.28)) { step = prev }
    }

    /// Step19's "I'm ready" handler. Persists the draft to SwiftData and
    /// advances to the celebration screen (tasksAdded), which then completes
    /// onboarding via `finishOnboarding` after its auto-advance delay.
    ///
    /// `isCommitting` guards against a double-tap (or a tap during the 280 ms
    /// step transition) re-running persistence, which would duplicate every
    /// RoutineTag and AI task.
    private func commit() {
        guard !isCommitting else { return }
        isCommitting = true
        OnboardingPersistence.commit(draft: draft, store: store, modelContext: modelContext)
        Analytics.track(.onboardingCommitted)
        // Now that profile fields are persisted to AppStore, re-identify
        // with the full trait set so PostHog person properties reflect
        // primary_need / neurodivergence / marketing_optin from this user.
        if let uid = AuthManager.shared.currentUserID {
            Analytics.identify(userID: uid, traits: store.analyticsTraits())
        }
        advance()
    }

    private func finishOnboarding() {
        let totalRoutines = draft.morningRoutines.count + draft.afternoonRoutines.count + draft.eveningRoutines.count
        Analytics.track(.onboardingCompleted(
            totalSteps: OnboardingStep.total,
            routinesCount: totalRoutines,
            tasksCount: draft.selectedTasks.count
        ))
        withAnimation(.easeInOut(duration: 0.32)) {
            store.hasCompletedOnboarding = true
        }
    }

    private func scheduleAutoProgress(for s: OnboardingStep) {
        guard let delay = s.autoAdvanceSeconds else { return }
        _Concurrency.Task {
            try? await _Concurrency.Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await MainActor.run {
                if OnboardingStep(rawValue: s.rawValue + 1) == nil {
                    finishOnboarding()
                } else {
                    advance()
                }
            }
        }
    }

    /// Returning-user path. Invoked when a signed-in user explicitly opts to
    /// skip the rest of onboarding from Step01 or Step05bCreateAccount.
    /// Marks onboarding complete without persisting draft profile fields
    /// (they're a returning user — their server-side profile already exists).
    /// Routing falls through to .paywall or .home depending on entitlement.
    private func skipToEnd() {
        Analytics.track(.onboardingSkipped(fromStep: step.rawValue, name: String(describing: step)))
        withAnimation(.easeInOut(duration: 0.32)) {
            store.hasCompletedOnboarding = true
        }
    }
}
