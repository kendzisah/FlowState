import SwiftUI

/// Collapsible parent card representing a single `RoutineGroup` (e.g.,
/// "Morning routine", "Workout"). Routines are energy-neutral; the group's
/// optional energy chip on the header is display-only.
///
/// Tapping the header toggles expand/collapse. Tapping a child's checkbox
/// marks the routine complete for today; the next call to
/// `RoutineScheduler.materializeToday` will create a fresh instance for
/// the following day.
struct RoutineSlotSection: View {
    let group: RoutineGroup
    let tasks: [Task]
    var onToggle: (Task) -> Void
    var onEdit: (Task) -> Void
    var onDelete: (Task) -> Void
    /// Long-press on the section header → "Add routine". Caller presents
    /// `EditRoutineSheet` in create mode seeded with this group.
    var onAddItem: ((RoutineGroup) -> Void)? = nil
    /// Long-press on the section header → "Edit group". Caller presents
    /// `EditRoutineGroupSheet` for this group.
    var onEditGroup: ((RoutineGroup) -> Void)? = nil
    /// Long-press on the section header → "Delete this group". Caller
    /// removes the group, its tags, and any materialized Tasks.
    var onDeleteGroup: ((RoutineGroup) -> Void)? = nil
    /// When true, rows render dimmed and the checkbox is non-interactive —
    /// used by the Calendar tab on days other than today, where the routine
    /// task hasn't been materialized yet. Edit/Delete via the row's
    /// contextMenu still work because they target the source `RoutineTag`.
    var isPreview: Bool = false
    /// Calendar "Start" → run the whole group through the timer. Nil hides the
    /// run control (e.g. on the Home tab or preview days).
    var onStartRun: ((RoutineGroup) -> Void)? = nil
    /// Calendar "Resume" → continue a paused run.
    var onResumeRun: ((RoutineGroup) -> Void)? = nil
    /// A paused run exists for this group → show Resume instead of Start.
    var isPausedRun: Bool = false
    /// Another session (a single-task timer or another run) is active → the
    /// Start button is shown disabled so the user knows it's momentarily unavailable.
    var runDisabled: Bool = false

    @Environment(\.palette) private var palette
    @State private var isExpanded: Bool = true

    /// Incomplete routines only — used to gate the run control (nothing to run
    /// once everything's done). Completed routines stay rendered (struck out)
    /// so a mis-tap can be undone by tapping again.
    private var activeTasks: [Task] { tasks.filter { !$0.isCompleted } }
    private var completed: Int { tasks.filter(\.isCompleted).count }
    private var total: Int { tasks.count }

    /// Render order: incomplete first (in their existing order), completed
    /// sink to the bottom — but each stays in place when toggled so undo is
    /// predictable. Preview days have no completion state, so order is moot.
    private var orderedTasks: [Task] {
        tasks.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.isCompleted != rhs.element.isCompleted {
                    return !lhs.element.isCompleted
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private var slotIcon: String {
        switch group.slot {
        case .morning:   return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening:   return "moon.fill"
        }
    }

    private var emojiOrIcon: AnyView {
        if let emoji = group.emoji, !emoji.isEmpty {
            return AnyView(Text(emoji).font(.system(size: 18)))
        }
        return AnyView(
            Image(systemName: slotIcon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(palette.textSecondary)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(orderedTasks, id: \.id) { task in
                        Divider().background(palette.border.opacity(0.4))
                        RoutineRow(
                            task: task,
                            isPreview: isPreview,
                            onToggle: { onToggle(task) },
                            onEdit: { onEdit(task) },
                            onDelete: { onDelete(task) }
                        )
                        .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.28), value: orderedTasks.map { "\($0.id)-\($0.isCompleted)" })

                runControl
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                .fill(palette.surface)
        )
        // Clip so the full-width run button's fill follows the card's rounded
        // bottom corners instead of poking out as square edges.
        .clipShape(RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
    }

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 12) {
                emojiOrIcon
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(group.title)
                            .font(AppFont.body)
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                        if let energy = group.energy {
                            energyChip(energy)
                        }
                    }
                    Text("\(completed)/\(total)")
                        .font(AppFont.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(palette.textDimmed)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(group.title), \(completed) of \(total) complete, \(isExpanded ? "collapse" : "expand")")
        .contextMenu {
            if let onAddItem {
                Button {
                    onAddItem(group)
                } label: {
                    Label("Add routine…", systemImage: "plus.circle")
                }
            }
            if let onEditGroup {
                Button {
                    onEditGroup(group)
                } label: {
                    Label("Edit group…", systemImage: "pencil")
                }
            }
            if let onDeleteGroup {
                Divider()
                Button(role: .destructive) {
                    onDeleteGroup(group)
                } label: {
                    Label("Delete group", systemImage: "trash")
                }
            }
        }
    }

    /// "Start routine · 30 min" / "Resume routine" footer. Only shown for the
    /// live (non-preview) day, when there's at least one task left to run and a
    /// run handler is wired.
    @ViewBuilder
    private var runControl: some View {
        if !isPreview, onStartRun != nil, !activeTasks.isEmpty {
            Divider().background(palette.border.opacity(0.4))
            Button {
                if isPausedRun { onResumeRun?(group) } else { onStartRun?(group) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isPausedRun ? "play.circle.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(runLabel)
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                }
                .foregroundStyle(runDisabled ? palette.textDimmed : palette.onEnergy)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity)
                .background(
                    (isPausedRun ? palette.parkedAccent : palette.energySteady)
                        .opacity(runDisabled ? 0.4 : 1.0)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .disabled(runDisabled)
            .accessibilityLabel(isPausedRun ? "Resume \(group.title)" : "Start \(group.title)")
        }
    }

    private var runLabel: String {
        if isPausedRun { return "Resume routine" }
        let minutes = max(group.runDurationSeconds / 60, 1)
        return "Start routine · \(minutes) min"
    }

    private func energyChip(_ energy: EnergyLevel) -> some View {
        HStack(spacing: 4) {
            Image(systemName: energy.iconName)
                .font(.system(size: 9, weight: .bold))
            Text(energy.shortLabel.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
        }
        .foregroundStyle(palette.onEnergy)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(energy.color(in: palette)))
    }
}

private struct RoutineRow: View {
    let task: Task
    var isPreview: Bool = false
    var onToggle: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: { if !isPreview { onToggle() } }) {
            HStack(spacing: 12) {
                Text(task.title)
                    .font(AppFont.body)
                    .foregroundStyle(isPreview
                                     ? palette.textSecondary
                                     : (task.isCompleted ? palette.textDimmed : palette.textPrimary))
                    .strikethrough(task.isCompleted && !isPreview, color: palette.textDimmed)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                ZStack {
                    Circle()
                        .stroke(isPreview
                                ? palette.border.opacity(0.5)
                                : (task.isCompleted ? palette.energySteady : palette.border),
                                lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if task.isCompleted && !isPreview {
                        Circle().fill(palette.energySteady).frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(palette.onEnergy)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(isPreview ? 0.7 : 1.0)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(task.title), \(isPreview ? "preview" : (task.isCompleted ? "completed" : "not completed"))")
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit routine…", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete routine", systemImage: "trash")
            }
        }
    }
}
