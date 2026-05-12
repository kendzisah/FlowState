import SwiftUI

struct Step16BuildingTasks: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void

    @Environment(\.palette) private var palette
    @State private var didStart = false

    var body: some View {
        VStack(spacing: 24) {
            // Pinned input chip — shows what the user submitted
            HStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                Text(truncated(draft.weeklyIntentText, max: 80))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.surface)
            )
            .padding(.horizontal, Geometry.horizontalPadding)
            .padding(.top, 60)

            Spacer()

            FoggyMascot(size: 110)

            Text("Building your tasks…")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.textPrimary)

            Spacer()
        }
        .onAppear {
            guard !didStart else { return }
            didStart = true
            run()
        }
    }

    private func run() {
        let started = Date()
        _Concurrency.Task {
            let tasks: [DraftTask]
            do {
                tasks = try await TaskExtractor.extract(from: draft.weeklyIntentText)
            } catch {
                tasks = TaskExtractor.ruleBasedFallback(from: draft.weeklyIntentText)
            }

            // Hold the loader for at least 800ms so it doesn't flash by.
            let elapsed = Date().timeIntervalSince(started)
            let minHold: TimeInterval = 0.8
            if elapsed < minHold {
                try? await _Concurrency.Task.sleep(nanoseconds: UInt64((minHold - elapsed) * 1_000_000_000))
            }

            await MainActor.run {
                draft.generatedTasks = tasks
                draft.selectedTaskIDs = Set(tasks.map(\.id)) // default = all selected
                onContinue()
            }
        }
    }

    private func truncated(_ s: String, max: Int) -> String {
        if s.count <= max { return s }
        return String(s.prefix(max)) + "…"
    }
}
