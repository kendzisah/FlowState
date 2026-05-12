import SwiftUI

struct TimeSlotSection: View {
    let slot: DayTimeSlot
    let items: [DayItem]
    let classifyingEventIDs: Set<UUID>
    var isAutoSortingAnytime: Bool = false
    let onAddTap: (DayTimeSlot) -> Void
    let onPickEnergy: (DayItem, EnergyLevel) -> Void
    let onAutoClassify: (DayItem) -> Void
    let onMoveToSlot: (DayItem, DayTimeSlot) -> Void
    var onAutoSortAnytime: (() -> Void)? = nil
    var onEditTask: ((Task) -> Void)? = nil
    var onDeleteTask: ((Task) -> Void)? = nil
    /// Optional grouped "Morning routine" card rendered above the items list
    /// when the slot is expanded. Collapsing the slot hides it along with
    /// everything else, so routines and tasks stay visually nested.
    var routineContent: AnyView? = nil
    /// Number of routine tasks bundled in `routineContent`. Folded into the
    /// header count so "MORNING (4)" reflects routines + regular items.
    var routineCount: Int = 0

    @State private var collapsed: Bool = false
    @Environment(\.palette) private var palette

    private var slotTint: Color {
        switch slot {
        case .anytime:   return palette.surface
        case .morning:   return palette.energySteady.opacity(0.25)
        case .afternoon: return palette.energyScattered.opacity(0.25)
        case .evening:   return palette.energyLocked.opacity(0.25)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                header
                if slot == .anytime, !items.isEmpty, onAutoSortAnytime != nil {
                    autoSortButton
                }
                Spacer(minLength: 0)
            }
            if !collapsed {
                VStack(spacing: 8) {
                    if let routineContent {
                        routineContent
                    }
                    if items.isEmpty {
                        if routineContent == nil {
                            emptyPlaceholder
                        }
                    } else {
                        ForEach(items) { item in
                            DayItemCard(
                                item: item,
                                currentSlot: slot,
                                isClassifying: classifyingID(for: item).map { classifyingEventIDs.contains($0) } ?? false,
                                onPickEnergy: { onPickEnergy(item, $0) },
                                onAutoClassify: { onAutoClassify(item) },
                                onMoveToSlot: { onMoveToSlot(item, $0) },
                                onEditTask: onEditTask,
                                onDeleteTask: onDeleteTask
                            )
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                collapsed.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: slot.iconName)
                    .font(.system(size: 12, weight: .bold))
                Text("\(slot.title.uppercased()) (\(items.count + routineCount))")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.4)
                Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(palette.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(slotTint))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(slot.title) section, \(items.count) items, \(collapsed ? "collapsed" : "expanded")")
    }

    private var autoSortButton: some View {
        Button {
            onAutoSortAnytime?()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 11, weight: .bold))
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isAutoSortingAnytime)
                Text(isAutoSortingAnytime ? "SORTING…" : "AUTO-SORT")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.0)
            }
            .foregroundStyle(palette.parkedAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(palette.parkedAccent.opacity(0.08))
                    .overlay(
                        Capsule().stroke(palette.parkedAccent.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.pressable)
        .disabled(isAutoSortingAnytime)
        .accessibilityLabel("Auto-sort all anytime items into morning, afternoon, or evening")
    }

    private func classifyingID(for item: DayItem) -> UUID? {
        if case .event(let e) = item { return e.id }
        return nil
    }

    private var emptyPlaceholder: some View {
        HStack {
            Text(slot.emptyStateCopy)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(palette.textDimmed)
            Spacer()
            Button {
                onAddTap(slot)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Add to \(slot.title)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(palette.border)
        )
    }
}
