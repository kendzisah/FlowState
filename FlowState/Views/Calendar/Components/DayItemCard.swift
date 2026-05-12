import SwiftUI

struct DayItemCard: View {
    let item: DayItem
    let currentSlot: DayTimeSlot
    let isClassifying: Bool
    let onPickEnergy: (EnergyLevel) -> Void
    let onAutoClassify: () -> Void
    let onMoveToSlot: (DayTimeSlot) -> Void
    /// Task-only edit + delete. Events are read-only references to the system
    /// calendar so these callbacks are simply ignored when the item is an event.
    var onEditTask: ((Task) -> Void)? = nil
    var onDeleteTask: ((Task) -> Void)? = nil

    @Environment(\.palette) private var palette

    private var timeLabel: String {
        if item.isAllDayLike { return "All day" }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: item.sortDate).lowercased()
    }

    private var isUserOverride: Bool {
        switch item {
        case .event(let e): return e.userOverrideEnergy
        case .task: return true   // tasks always have a user-set energy
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeLabel)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)
                Image(systemName: item.sourceIcon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.textDimmed)
            }
            .frame(width: 52, alignment: .trailing)

            RoundedRectangle(cornerRadius: 3)
                .fill((item.energy ?? .steady).color(in: palette))
                .frame(width: 4)
                .frame(maxHeight: .infinity)
                .opacity(item.energy == nil ? 0.3 : 1.0)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(2)

                EnergyBadgeMenu(
                    current: item.energy,
                    isUserOverride: isUserOverride,
                    isClassifying: isClassifying,
                    onPick: onPickEnergy,
                    onAutoClassify: onAutoClassify
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(minHeight: 64)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
        .contextMenu {
            if case .task(let task, _) = item {
                if let onEditTask {
                    Button {
                        onEditTask(task)
                    } label: {
                        Label("Edit task…", systemImage: "pencil")
                    }
                }
            }
            Section("Move to") {
                ForEach(DayTimeSlot.allCases) { slot in
                    if slot != currentSlot {
                        Button {
                            onMoveToSlot(slot)
                        } label: {
                            Label(slot.title, systemImage: slot.iconName)
                        }
                    }
                }
            }
            if case .task(let task, _) = item, let onDeleteTask {
                Divider()
                Button(role: .destructive) {
                    onDeleteTask(task)
                } label: {
                    Label("Delete task", systemImage: "trash")
                }
            }
        }
    }
}
