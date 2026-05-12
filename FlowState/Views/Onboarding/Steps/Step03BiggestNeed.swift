import SwiftUI

struct Step03BiggestNeed: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void

    @Environment(\.palette) private var palette

    private struct Option: Identifiable {
        let id: PrimaryNeed
        let label: String
    }

    private let options: [Option] = [
        .init(id: .organize,    label: "Organize my day & time"),
        .init(id: .remember,    label: "Remember my tasks"),
        .init(id: .prioritize,  label: "Prioritize my to-dos"),
        .init(id: .routines,    label: "Build & stick to routines"),
        .init(id: .focus,       label: "Support focus work")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer().frame(height: 80)

            VStack(alignment: .leading, spacing: 8) {
                Text("What do you need most right now?")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(AppFont.titleTracking)
                    .foregroundStyle(palette.textPrimary)
                Text("This helps us tailor FlowState to how you work.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(palette.textSecondary)
            }

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(options) { opt in
                        OnbOptionCard(
                            title: opt.label,
                            isSelected: draft.primaryNeed == opt.id
                        ) {
                            draft.primaryNeed = opt.id
                            // Snappy advance — Tiimo pattern
                            _Concurrency.Task {
                                try? await _Concurrency.Task.sleep(nanoseconds: 180_000_000)
                                await MainActor.run { onContinue() }
                            }
                        }
                    }
                }
            }

            Button {
                draft.primaryNeed = .other
                onContinue()
            } label: {
                Text("Something else")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                    .underline()
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.bottom, 24)
    }
}
