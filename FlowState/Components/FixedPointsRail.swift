import SwiftUI

/// A compact, chronological list of today's *anchored* items — imported
/// calendar events and tasks the user committed to a specific clock time.
/// It sits above the energy lanes on the home screen so fixed commitments
/// stay visible without forcing the whole day onto a Tiimo-style timeline.
///
/// Anchored items keep an energy chip (so a 9:30 standup still reads as
/// "scattered") but are sorted by time, never floated by energy match.
struct FixedPointsRail: View {
    let items: [DayItem]
    /// Tapping a task row opens the editor. Event rows are read-only mirrors
    /// of the system calendar, so they don't call this.
    var onTapTask: (Task) -> Void

    @Environment(\.palette) private var palette

    /// All-day items first, then timed items in chronological order.
    private var sortedItems: [DayItem] {
        items.sorted { lhs, rhs in
            if lhs.isAllDayLike != rhs.isAllDayLike { return lhs.isAllDayLike }
            return lhs.sortDate < rhs.sortDate
        }
    }

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                header
                VStack(spacing: 8) {
                    ForEach(sortedItems) { item in
                        row(for: item)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "pin.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(palette.textSecondary)
            Text("FIXED POINTS TODAY")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(palette.textSecondary)
        }
    }

    @ViewBuilder
    private func row(for item: DayItem) -> some View {
        switch item {
        case .task(let task, _):
            Button {
                onTapTask(task)
            } label: {
                rowContent(for: item)
            }
            .buttonStyle(.pressable)
            .accessibilityHint("Edit task")
        case .event:
            rowContent(for: item)
        }
    }

    private func rowContent(for item: DayItem) -> some View {
        let energy = item.energy ?? .steady
        return HStack(spacing: 12) {
            Text(timeLabel(for: item))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(palette.textSecondary)
                .frame(width: 54, alignment: .trailing)

            RoundedRectangle(cornerRadius: 3)
                .fill(energy.color(in: palette))
                .frame(width: 4)
                .frame(maxHeight: .infinity)
                .opacity(item.energy == nil ? 0.3 : 1.0)

            Text(item.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            energyChip(energy, dim: item.energy == nil)
        }
        .frame(minHeight: 36)
        .contentShape(Rectangle())
    }

    private func energyChip(_ level: EnergyLevel, dim: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: level.iconName)
                .font(.system(size: 10, weight: .bold))
            Text(level.shortLabel)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(level.color(in: palette))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(level.color(in: palette).opacity(0.14))
        )
        .opacity(dim ? 0.5 : 1.0)
    }

    private func timeLabel(for item: DayItem) -> String {
        if item.isAllDayLike { return "All day" }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: item.sortDate).lowercased()
    }
}
