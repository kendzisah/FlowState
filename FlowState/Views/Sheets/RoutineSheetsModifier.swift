import SwiftUI
import SwiftData

/// Collapses the four routine-related `.sheet(item:)` modifiers into one
/// `ViewModifier`. Two SwiftUI bodies (TaskListView, CalendarTabView) both
/// present the same set of sheets, and the long chained modifier list inside
/// those views was hitting the SwiftUI source-editor's type-check budget —
/// causing phantom "Cannot find 'EditRoutineGroupSheet'" errors in Xcode.
/// Grouping the four sheets into a single typed modifier shortens the chain
/// and gives the typechecker less to resolve per pass.
struct RoutineSheetsModifier: ViewModifier {
    @Binding var editingRoutine: RoutineTag?
    @Binding var addingInGroup: RoutineGroup?
    @Binding var addingGroupSlot: RoutineSlot?
    @Binding var editingGroup: RoutineGroup?

    let palette: Palette
    /// Resolves a routine's materialized Task for today, when one exists.
    /// `EditRoutineSheet` uses it to keep the edited title in sync with the
    /// already-scheduled card on the home tab.
    // Module-qualified to disambiguate from `_Concurrency.Task` — without
    // this, Xcode's source-editor typechecker has to resolve `Task` against
    // both candidates at every reference, blowing the 4-sheet inference
    // budget and producing phantom "Cannot find EditRoutineGroupSheet" /
    // "Cannot infer key path type" errors. CLI builds resolve fine either
    // way; this is purely to keep the IDE indexer's life simple.
    let todayInstance: (RoutineTag) -> FlowState.Task?

    func body(content: Content) -> some View {
        content
            .sheet(item: $editingRoutine, content: editRoutineSheet(for:))
            .sheet(item: $addingInGroup, content: addInGroupSheet(for:))
            .sheet(item: $addingGroupSlot, content: addGroupSlotSheet(for:))
            .sheet(item: $editingGroup, content: editGroupSheet(for:))
    }

    // Each sheet's content lives in its own `@ViewBuilder` function so the
    // editor's typechecker resolves four independent `some View` returns
    // instead of one nested 4-deep generic chain. Same runtime semantics;
    // the `.environment(\.palette, palette)` stays inside each closure so
    // custom EnvironmentKey propagation still works across modal boundaries.

    @ViewBuilder
    private func editRoutineSheet(for routine: RoutineTag) -> some View {
        EditRoutineSheet(routine: routine, materializedToday: todayInstance(routine))
            .environment(\.palette, palette)
    }

    @ViewBuilder
    private func addInGroupSheet(for group: RoutineGroup) -> some View {
        EditRoutineSheet(defaultGroup: group)
            .environment(\.palette, palette)
    }

    @ViewBuilder
    private func addGroupSlotSheet(for slot: RoutineSlot) -> some View {
        EditRoutineGroupSheet(defaultSlot: slot)
            .environment(\.palette, palette)
    }

    @ViewBuilder
    private func editGroupSheet(for group: RoutineGroup) -> some View {
        EditRoutineGroupSheet(group: group)
            .environment(\.palette, palette)
    }
}

extension View {
    func routineSheets(
        editingRoutine: Binding<RoutineTag?>,
        addingInGroup: Binding<RoutineGroup?>,
        addingGroupSlot: Binding<RoutineSlot?>,
        editingGroup: Binding<RoutineGroup?>,
        palette: Palette,
        todayInstance: @escaping (RoutineTag) -> FlowState.Task?
    ) -> some View {
        modifier(RoutineSheetsModifier(
            editingRoutine: editingRoutine,
            addingInGroup: addingInGroup,
            addingGroupSlot: addingGroupSlot,
            editingGroup: editingGroup,
            palette: palette,
            todayInstance: todayInstance
        ))
    }
}
