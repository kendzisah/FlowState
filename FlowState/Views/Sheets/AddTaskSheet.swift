import SwiftUI
import SwiftData

struct AddTaskSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var selectedLevel: EnergyLevel? = nil
    @State private var manuallyPicked: Bool = false
    @State private var suggestion: TitleClassifier.Suggestion?
    @State private var debounceTask: _Concurrency.Task<Void, Never>?

    private var defaultLevel: EnergyLevel {
        let current = store.energyLevel ?? .steady
        return EnergyLevel.taskAssignable.contains(current) ? current : .steady
    }

    private var effectiveLevel: EnergyLevel {
        if manuallyPicked { return selectedLevel ?? defaultLevel }
        return suggestion?.level ?? selectedLevel ?? defaultLevel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text("New task")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(AppFont.titleTracking)
                    .foregroundStyle(palette.textPrimary)

                TextField(AppStrings.addTaskTitlePlaceholder, text: $title, axis: .vertical)
                    .font(AppFont.body)
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1...3)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                            .fill(palette.surfaceAlt)
                    )
                    .onChange(of: title) { _, newValue in
                        scheduleClassify(for: newValue)
                    }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("Energy")
                        .font(AppFont.caption)
                        .tracking(0.6)
                        .foregroundStyle(palette.textSecondary)
                    if !manuallyPicked, let s = suggestion {
                        Text("\u{00B7} suggested: \(s.level.shortLabel)")
                            .font(AppFont.caption)
                            .foregroundStyle(palette.captionPulse)
                    }
                }

                HStack(spacing: 10) {
                    ForEach(EnergyLevel.taskAssignable, id: \.self) { level in
                        chip(level)
                    }
                }
            }

            Spacer(minLength: 0)

            Button(action: save) {
                Text(AppStrings.addTaskSaveAction)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.onEnergy)
                    .frame(maxWidth: .infinity, minHeight: Geometry.minTapTarget)
                    .background(
                        RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                            .fill(canSave ? effectiveLevel.color(in: palette) : palette.surfaceAlt)
                    )
            }
            .buttonStyle(.pressable)
            .disabled(!canSave)
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 24)
        .presentationDetents([.fraction(0.5), .medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Geometry.sheetRadius)
        .presentationBackground(palette.surface)
        .onDisappear { debounceTask?.cancel() }
    }

    private func chip(_ level: EnergyLevel) -> some View {
        let on = effectiveLevel == level
        let isSuggested = !manuallyPicked && suggestion?.level == level
        return Button {
            selectedLevel = level
            manuallyPicked = true
        } label: {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 6) {
                    Image(systemName: level.iconName)
                        .font(.system(size: 13, weight: .semibold))
                    Text(level.shortLabel)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(on ? palette.onEnergy : palette.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .background(
                    Capsule().fill(on ? level.color(in: palette) : palette.surfaceAlt)
                )

                if isSuggested {
                    Circle()
                        .fill(palette.captionPulse)
                        .frame(width: 6, height: 6)
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.pressable)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func scheduleClassify(for newTitle: String) {
        debounceTask?.cancel()
        debounceTask = _Concurrency.Task { @MainActor in
            try? await _Concurrency.Task.sleep(for: .milliseconds(600))
            if _Concurrency.Task.isCancelled { return }
            let s = TitleClassifier.classify(newTitle)
            withAnimation(.easeInOut(duration: 0.18)) {
                self.suggestion = s
            }
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let level = effectiveLevel
        let assignable = EnergyLevel.taskAssignable.contains(level) ? level : .steady
        let task = Task(title: trimmed, energyTag: assignable)
        context.insert(task)
        try? context.save()
        dismiss()
    }
}
