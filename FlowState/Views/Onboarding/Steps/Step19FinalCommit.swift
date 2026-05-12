import SwiftUI

struct Step19FinalCommit: View {
    @Bindable var draft: OnboardingDraft
    let onCommit: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer().frame(height: 60)

            Text("Lastly, commit to get this done!")
                .font(.system(size: 24, weight: .bold))
                .tracking(AppFont.titleTracking)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(draft.allSelectedRoutines) { opt in
                        row(emoji: opt.emoji, label: opt.label)
                    }
                    ForEach(draft.selectedTasks) { t in
                        row(emoji: emoji(for: t), label: t.title)
                    }
                    if draft.allSelectedRoutines.isEmpty && draft.selectedTasks.isEmpty {
                        Text("You can add routines and tasks any time from the home screen.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(palette.textSecondary)
                            .padding(.top, 16)
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer(minLength: 8)

            CommitReadyButton(action: onCommit)
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func row(emoji: String, label: String) -> some View {
        HStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 22))
                .frame(width: 28)
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(palette.textPrimary)
            Spacer()
        }
        .padding(.vertical, 6)
    }

    /// Tasks don't carry an emoji on the draft. Map by suggested energy so
    /// each item still gets a visual anchor in the flat list.
    private func emoji(for task: DraftTask) -> String {
        switch task.suggestedEnergy {
        case .scattered: return "✨"
        case .steady:    return "🎯"
        case .locked:    return "🧠"
        case .foggy:     return "☁️"
        case .none:      return "📌"
        }
    }
}

/// Tiimo-style pill button with a leading circular arrow chip. Behaves like
/// OnbPrimaryButton but with the dedicated visual treatment used only on the
/// final commit step.
private struct CommitReadyButton: View {
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            ZStack {
                Text("I'm ready")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.onEnergy)
                    .frame(maxWidth: .infinity, minHeight: Geometry.minTapTarget)

                HStack {
                    ZStack {
                        Circle()
                            .fill(palette.onEnergy)
                            .frame(width: 36, height: 36)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(palette.energySteady)
                    }
                    .padding(.leading, 6)
                    Spacer()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                    .fill(palette.energySteady)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("I'm ready")
    }
}
