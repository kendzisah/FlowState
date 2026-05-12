import SwiftUI

private enum RoutineCatalog {
    static let morning: [RoutineOption] = [
        .init(id: "wake",       emoji: "🌅", label: "Wake up"),
        .init(id: "prayer_am",  emoji: "🌙", label: "Morning prayer"),
        .init(id: "bed",        emoji: "🛏",  label: "Make bed"),
        .init(id: "teeth_am",   emoji: "🪥", label: "Brush teeth"),
        .init(id: "water_am",   emoji: "💧", label: "Drink water"),
        .init(id: "meds",       emoji: "💊", label: "Take meds"),
        .init(id: "shower_am",  emoji: "🚿", label: "Shower"),
        .init(id: "dress",      emoji: "👕", label: "Get dressed"),
        .init(id: "breakfast",  emoji: "🍳", label: "Breakfast"),
        .init(id: "coffee_am",  emoji: "☕", label: "Have coffee"),
        .init(id: "plan_am",    emoji: "📋", label: "Plan your day"),
        .init(id: "tidy_am",    emoji: "🧹", label: "Quick tidy"),
        .init(id: "commute_in", emoji: "🚗", label: "Commute to work")
    ]

    static let afternoon: [RoutineOption] = [
        .init(id: "plan_pm",     emoji: "📋", label: "Plan your day"),
        .init(id: "study",       emoji: "📚", label: "Study"),
        .init(id: "work_start",  emoji: "💻", label: "Start work"),
        .init(id: "emails",      emoji: "💬", label: "Check emails"),
        .init(id: "deep_work",   emoji: "🧠", label: "Deep work"),
        .init(id: "lunch",       emoji: "🥗", label: "Lunch"),
        .init(id: "coffee_pm",   emoji: "☕", label: "Coffee break"),
        .init(id: "water_pm",    emoji: "💧", label: "Drink water"),
        .init(id: "workout_pm",  emoji: "💪", label: "Workout"),
        .init(id: "kids",        emoji: "👶", label: "Pick up kids"),
        .init(id: "groceries",   emoji: "🛒", label: "Grocery shopping"),
        .init(id: "social",      emoji: "👋", label: "Socialize"),
        .init(id: "commute_out", emoji: "🚗", label: "Commute home")
    ]

    static let evening: [RoutineOption] = [
        .init(id: "dinner",     emoji: "🍲", label: "Have dinner"),
        .init(id: "workout_ev", emoji: "🏋️", label: "Workout"),
        .init(id: "yoga",       emoji: "🧘", label: "Yoga"),
        .init(id: "homework",   emoji: "📝", label: "Homework"),
        .init(id: "tidy_ev",    emoji: "🧹", label: "Quick tidy"),
        .init(id: "laundry",    emoji: "🧺", label: "Do laundry"),
        .init(id: "shower_ev",  emoji: "🚿", label: "Take a shower"),
        .init(id: "prayer_ev",  emoji: "🙏", label: "Evening prayer"),
        .init(id: "journal",    emoji: "📓", label: "Journal"),
        .init(id: "tv",         emoji: "📺", label: "Watch tv"),
        .init(id: "read",       emoji: "📖", label: "Read a book"),
        .init(id: "dog",        emoji: "🐕", label: "Walk the dog"),
        .init(id: "tea",        emoji: "🍵", label: "Drink tea"),
        .init(id: "teeth_ev",   emoji: "🪥", label: "Brush teeth"),
        .init(id: "bedtime",    emoji: "🥱", label: "Go to bed")
    ]

    /// Picks 3–4 sensible defaults per slot.
    static func suggestions(for slot: RoutineSlot) -> [RoutineOption] {
        switch slot {
        case .morning:   return Array(morning.prefix(4))   // wake, bed, teeth, water
        case .afternoon: return [afternoon[0], afternoon[2], afternoon[5], afternoon[7]] // plan, work, lunch, water
        case .evening:   return [evening[0], evening[7], evening[9], evening[12]]        // dinner, journal, read, teeth
        }
    }
}

struct Step10MorningRoutines: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void

    var body: some View {
        @Bindable var bindable = draft
        RoutineStepScaffold(
            chip: "MORNING",
            chipIcon: "sunrise.fill",
            title: "Add morning routines to your schedule.",
            subtitle: "Pick the habits that start your day strong.",
            options: RoutineCatalog.morning,
            selection: $bindable.morningRoutines,
            onSuggest: {
                bindable.morningRoutines.formUnion(RoutineCatalog.suggestions(for: .morning))
            },
            onContinue: onContinue
        )
    }
}

struct Step11AfternoonRoutines: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void

    var body: some View {
        @Bindable var bindable = draft
        RoutineStepScaffold(
            chip: "AFTERNOON",
            chipIcon: "sun.max.fill",
            title: "Add daytime routines to your schedule.",
            subtitle: "Stay productive, balanced, and on track.",
            options: RoutineCatalog.afternoon,
            selection: $bindable.afternoonRoutines,
            onSuggest: {
                bindable.afternoonRoutines.formUnion(RoutineCatalog.suggestions(for: .afternoon))
            },
            onContinue: onContinue
        )
    }
}

struct Step12EveningRoutines: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void

    var body: some View {
        @Bindable var bindable = draft
        RoutineStepScaffold(
            chip: "EVENING",
            chipIcon: "moon.fill",
            title: "Add evening routines to your schedule.",
            subtitle: "Wind down with habits that help you rest.",
            options: RoutineCatalog.evening,
            selection: $bindable.eveningRoutines,
            onSuggest: {
                bindable.eveningRoutines.formUnion(RoutineCatalog.suggestions(for: .evening))
            },
            onContinue: onContinue
        )
    }
}
