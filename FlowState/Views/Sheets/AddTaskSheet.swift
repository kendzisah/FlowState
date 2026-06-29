import SwiftUI
import SwiftData

struct AddTaskSheet: View {
    /// When non-nil, the sheet edits this task in place instead of inserting a new one.
    /// Title/energy/manuallyPicked are seeded from the task on first render.
    var editing: Task? = nil

    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var selectedLevel: EnergyLevel? = nil
    @State private var manuallyPicked: Bool = false
    @State private var suggestion: TitleClassifier.Suggestion?
    @State private var debounceTask: _Concurrency.Task<Void, Never>?
    @State private var didSeed: Bool = false

    @State private var scheduledDate: Date? = nil
    @State private var recurrence: Recurrence = .none
    @State private var showDatePicker: Bool = false
    @State private var showDeleteConfirm: Bool = false

    private var isEditing: Bool { editing != nil }

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
                Text(isEditing ? "Edit task" : "New task")
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

            scheduleRow
            recurrenceRow

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                if isEditing {
                    Button { showDeleteConfirm = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(palette.energyScattered)
                            .frame(width: Geometry.minTapTarget, height: Geometry.minTapTarget)
                            .background(
                                RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                                    .stroke(palette.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Delete task")
                }

                Button(action: save) {
                    Text(isEditing ? "Save changes" : AppStrings.addTaskSaveAction)
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
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 24)
        .firstTimeTooltip(
            id: "addTask.energy",
            title: "Pick an energy",
            body: "FlowState matches tasks to how you feel. Scattered for quick wins, steady for normal work, locked-in for deep focus. We'll suggest one based on the title — accept or pick your own."
        )
        .presentationDetents([.fraction(0.7), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Geometry.sheetRadius)
        .presentationBackground(palette.surface)
        .onAppear { seedFromEditingIfNeeded() }
        .onDisappear { debounceTask?.cancel() }
        .alert("Delete task?", isPresented: $showDeleteConfirm, presenting: editing) { task in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                context.delete(task)
                context.saveAndSync()
                dismiss()
            }
        } message: { task in
            Text("\u{201C}\(task.title)\u{201D} will be removed. This can't be undone.")
        }
    }

    private func seedFromEditingIfNeeded() {
        guard let task = editing, !didSeed else { return }
        title = task.title
        selectedLevel = task.energyTag
        manuallyPicked = true
        scheduledDate = task.scheduledDate
        recurrence = task.recurrence
        didSeed = true
    }

    // MARK: - Schedule + Repeat rows

    private var scheduleRow: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showDatePicker.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 22)
                    Text("Schedule")
                        .font(AppFont.body)
                        .foregroundStyle(palette.textPrimary)
                    Spacer()
                    if let scheduledDate {
                        Text(scheduleLabel(scheduledDate))
                            .font(AppFont.body)
                            .foregroundStyle(palette.textSecondary)
                    } else {
                        Text("Not scheduled")
                            .font(AppFont.body)
                            .foregroundStyle(palette.textDimmed)
                    }
                    Image(systemName: showDatePicker ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(palette.textDimmed)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)

            if showDatePicker {
                VStack(spacing: 8) {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { scheduledDate ?? defaultScheduledDate() },
                            set: { scheduledDate = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(palette.energySteady)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if scheduledDate != nil {
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                scheduledDate = nil
                            }
                        } label: {
                            Text("Clear schedule")
                                .font(AppFont.caption)
                                .foregroundStyle(palette.energyScattered)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                .fill(palette.surfaceAlt)
        )
    }

    private var recurrenceRow: some View {
        Menu {
            ForEach(Recurrence.allCases) { option in
                Button {
                    recurrence = option
                } label: {
                    if option == recurrence {
                        Label(option.menuLabel, systemImage: "checkmark")
                    } else {
                        Text(option.menuLabel)
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 22)
                Text("Repeat")
                    .font(AppFont.body)
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text(recurrence.menuLabel)
                    .font(AppFont.body)
                    .foregroundStyle(recurrence == .none ? palette.textDimmed : palette.textSecondary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(palette.textDimmed)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                    .fill(palette.surfaceAlt)
            )
        }
    }

    private func scheduleLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        if cal.isDateInToday(date) {
            f.dateFormat = "'Today,' h:mm a"
        } else if cal.isDateInTomorrow(date) {
            f.dateFormat = "'Tomorrow,' h:mm a"
        } else {
            f.dateFormat = "MMM d, h:mm a"
        }
        return f.string(from: date)
    }

    private func defaultScheduledDate() -> Date {
        let cal = Calendar.current
        let now = Date()
        let nineToday = cal.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        let inOneHour = cal.date(byAdding: .hour, value: 1, to: now) ?? now
        return max(nineToday, inOneHour)
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

        if let task = editing {
            var changed: [String] = []
            if task.title != trimmed { changed.append("title") }
            if task.energyTag != assignable { changed.append("energy") }
            if task.scheduledDate != scheduledDate { changed.append("schedule") }
            if task.recurrence != recurrence { changed.append("recurrence") }
            task.title = trimmed
            task.energyTag = assignable
            task.scheduledDate = scheduledDate
            task.isAnchored = scheduledDate != nil
            task.recurrence = recurrence
            task.markDirty()
            Analytics.track(.taskEdited(taskID: task.id.uuidString, changedFields: changed))
        } else {
            let task = Task(title: trimmed, energyTag: assignable)
            task.scheduledDate = scheduledDate
            task.isAnchored = scheduledDate != nil
            task.recurrence = recurrence
            context.insert(task)
            Analytics.track(.taskCreated(
                source: "manual",
                energyLevel: assignable.rawValue,
                hasDuration: scheduledDate != nil
            ))
        }
        context.saveAndSync()
        dismiss()
    }
}
