import SwiftUI

struct Step04Neurodivergence: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void

    @Environment(\.palette) private var palette

    private struct Option: Identifiable {
        let id: NeurodivergenceSelfID
        let label: String
    }

    private let options: [Option] = [
        .init(id: .yes,     label: "I am neurodivergent"),
        .init(id: .thinkSo, label: "I think I am"),
        .init(id: .no,      label: "I am not neurodivergent")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer().frame(height: 80)

            VStack(alignment: .leading, spacing: 8) {
                Text("Are you neurodivergent?")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(AppFont.titleTracking)
                    .foregroundStyle(palette.textPrimary)
                Text("FlowState is built to support different brains. Pick what feels closest — there's no wrong answer.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(palette.textSecondary)
            }

            VStack(spacing: 10) {
                ForEach(options) { opt in
                    OnbOptionCard(
                        title: opt.label,
                        isSelected: draft.neurodivergenceSelfId == opt.id
                    ) {
                        draft.neurodivergenceSelfId = opt.id
                        Analytics.track(.onboardingNeurodivergence(value: opt.id.rawValue))
                        _Concurrency.Task {
                            try? await _Concurrency.Task.sleep(nanoseconds: 180_000_000)
                            await MainActor.run { onContinue() }
                        }
                    }
                }
            }

            Spacer()

            Button {
                draft.neurodivergenceSelfId = .unknown
                Analytics.track(.onboardingNeurodivergence(value: NeurodivergenceSelfID.unknown.rawValue))
                onContinue()
            } label: {
                Text("I don't know")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                    .underline()
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.bottom, 24)
    }
}
