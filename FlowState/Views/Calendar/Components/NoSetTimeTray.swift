import SwiftUI

/// The "No set time" tray on the Schedule tab — items with no committed clock
/// time (all-day events, anytime tasks). Replaces the old ANYTIME period
/// bucket; keeps the energy AUTO-SORT affordance that distributes these items
/// into the day. Framed as "no set time," not a fourth time-of-day bucket.
struct NoSetTimeTray: View {
    let items: [DayItem]
    let classifyingEventIDs: Set<UUID>
    var isAutoSorting: Bool = false
    let onPickEnergy: (DayItem, EnergyLevel) -> Void
    let onAutoClassify: (DayItem) -> Void
    var onReschedule: ((Task) -> Void)? = nil
    var onAutoSortAll: (() -> Void)? = nil
    var onEditTask: ((Task) -> Void)? = nil
    var onDeleteTask: ((Task) -> Void)? = nil
    let onAdd: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if items.isEmpty {
                emptyPlaceholder
            } else {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        DayItemCard(
                            item: item,
                            isClassifying: isClassifying(item),
                            onPickEnergy: { onPickEnergy(item, $0) },
                            onAutoClassify: { onAutoClassify(item) },
                            onReschedule: onReschedule,
                            onEditTask: onEditTask,
                            onDeleteTask: onDeleteTask
                        )
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 12, weight: .bold))
            Text("NO SET TIME (\(items.count))")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.4)
            if !items.isEmpty, onAutoSortAll != nil {
                autoSortButton
            }
            Spacer(minLength: 0)
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Add an item with no set time")
        }
        .foregroundStyle(palette.textPrimary)
    }

    private var autoSortButton: some View {
        Button { onAutoSortAll?() } label: {
            HStack(spacing: 5) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 11, weight: .bold))
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isAutoSorting)
                Text(isAutoSorting ? "SORTING…" : "AUTO-SORT")
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
        .disabled(isAutoSorting)
        .accessibilityLabel("Auto-sort items into the day by energy")
    }

    private var emptyPlaceholder: some View {
        HStack {
            Text("Nothing without a time. Add something, or leave it clear.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(palette.textDimmed)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(palette.border)
        )
    }

    private func isClassifying(_ item: DayItem) -> Bool {
        if case .event(let event) = item {
            return classifyingEventIDs.contains(event.id)
        }
        return false
    }
}
