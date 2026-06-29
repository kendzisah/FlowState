import SwiftUI

struct Step17PickTasks: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer().frame(height: 70)

            HStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                Text(truncated(draft.weeklyIntentText, max: 80))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: 4)
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textDimmed)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.surface)
            )

            Text("Pick the tasks for your plan.")
                .font(.system(size: 26, weight: .bold))
                .tracking(AppFont.titleTracking)
                .foregroundStyle(palette.textPrimary)

            ScrollView {
                VStack(spacing: 8) {
                    if draft.generatedTasks.isEmpty {
                        Text("We couldn't extract any tasks from your input. You can add them later from the home screen.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(palette.textSecondary)
                            .padding(.top, 24)
                    } else {
                        ForEach(draft.generatedTasks) { t in
                            TaskRow(task: t, isSelected: draft.selectedTaskIDs.contains(t.id)) {
                                if draft.selectedTaskIDs.contains(t.id) {
                                    draft.selectedTaskIDs.remove(t.id)
                                } else {
                                    draft.selectedTaskIDs.insert(t.id)
                                }
                            }
                        }
                    }
                }
            }

            // When nothing could be extracted there's nothing to pick, so the
            // CTA becomes a plain "Next" that lets the user move on rather than
            // a disabled "Add tasks (0)" that would trap them.
            if draft.generatedTasks.isEmpty {
                OnbPrimaryButton(
                    title: "Next",
                    enabled: true,
                    action: onContinue
                )
            } else {
                OnbPrimaryButton(
                    title: "Add tasks (\(draft.selectedTaskIDs.count))",
                    enabled: !draft.selectedTaskIDs.isEmpty,
                    action: onContinue
                )
            }
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.bottom, 24)
    }

    private func truncated(_ s: String, max: Int) -> String {
        if s.count <= max { return s }
        return String(s.prefix(max)) + "…"
    }
}

private struct TaskRow: View {
    let task: DraftTask
    let isSelected: Bool
    let onToggle: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: (task.suggestedEnergy ?? .steady).iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle((task.suggestedEnergy ?? .steady).color(in: palette))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(palette.surface)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    Text(task.category)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(palette.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    Circle()
                        .stroke(isSelected ? palette.captionPulse : palette.border, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(palette.captionPulse)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(palette.onEnergy)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
