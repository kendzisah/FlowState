import SwiftUI

struct TaskCard: View {
    let task: Task
    let parked: ParkedTask?
    let isMatching: Bool
    let namespace: Namespace.ID
    var onPrimary: () -> Void
    var onSchedule: (() -> Void)? = nil
    var onUnschedule: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @Environment(\.palette) private var palette

    private var scheduledLabel: String? {
        guard let date = task.scheduledDate else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f.string(from: date)
    }

    var body: some View {
        Button(action: onPrimary) {
            HStack(spacing: 14) {
                Circle()
                    .fill(task.energyTag.color(in: palette))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(AppFont.body)
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    if let parked {
                        HStack(spacing: 4) {
                            Image(systemName: "brain")
                                .font(.system(size: 11, weight: .semibold))
                            Text("parked · \(parkedDuration(parked))")
                        }
                        .font(AppFont.caption)
                        .foregroundStyle(palette.textDimmed)
                    } else if let scheduledLabel {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11, weight: .semibold))
                            Text(scheduledLabel)
                        }
                        .font(AppFont.caption)
                        .foregroundStyle(palette.textDimmed)
                    }
                }

                Spacer(minLength: 8)

                Text(parked == nil ? "Start" : "Resume")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.onEnergy)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(task.energyTag.color(in: palette))
                    )
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: Geometry.taskCardMinHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
            .opacity(isMatching ? 1.0 : 0.6)
        }
        .buttonStyle(.pressable)
        .matchedGeometryEffect(id: task.id, in: namespace)
        .accessibilityLabel("\(task.title), \(parked == nil ? "start" : "resume")")
        .contextMenu {
            if let onEdit {
                Button {
                    onEdit()
                } label: {
                    Label("Edit task…", systemImage: "pencil")
                }
            }
            if let onSchedule {
                Button {
                    onSchedule()
                } label: {
                    Label(task.scheduledDate == nil ? "Schedule…" : "Reschedule…",
                          systemImage: "calendar.badge.plus")
                }
            }
            if task.scheduledDate != nil, let onUnschedule {
                Button(role: .destructive) {
                    onUnschedule()
                } label: {
                    Label("Unschedule", systemImage: "calendar.badge.minus")
                }
            }
            if let onDelete {
                Divider()
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete task", systemImage: "trash")
                }
            }
        }
    }

    private func parkedDuration(_ p: ParkedTask) -> String {
        let mins = p.elapsedSeconds / 60
        return mins < 1 ? "<1m in" : "\(mins)m in"
    }
}
