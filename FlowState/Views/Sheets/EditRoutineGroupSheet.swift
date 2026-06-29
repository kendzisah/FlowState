import SwiftUI
import SwiftData

/// Editor for a `RoutineGroup`. Dual create/edit shape mirrors
/// `EditRoutineSheet`: when `group` is non-nil the sheet edits in place,
/// otherwise it inserts a new group in `defaultSlot`.
///
/// Group-level energy is display-only — it tags the header chip but does not
/// change the energy of materialized child Tasks (which stay `.steady` so
/// routines remain excluded from the energy-match sort).
struct EditRoutineGroupSheet: View {
    var group: RoutineGroup? = nil
    var defaultSlot: RoutineSlot = .morning

    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var emoji: String = ""
    @State private var slot: RoutineSlot = .morning
    @State private var reminderTime: Date = Date()
    @State private var recurrence: Recurrence = .daily
    @State private var energy: EnergyLevel? = nil
    @State private var durationMinutes: Int = 30
    @State private var didSeed: Bool = false
    @State private var showDeleteConfirm: Bool = false

    private var isEditing: Bool { group != nil }

    /// Run-length presets (minutes) offered in the duration menu.
    private static let durationPresets: [Int] = [5, 10, 15, 20, 30, 45, 60, 90]

    /// Emojis we auto-seeded as defaults. Only overwrite the emoji field when
    /// the user changes the time if the current emoji is still one of these —
    /// otherwise we'd clobber a user-typed emoji.
    private static let timeEmojis: Set<String> = ["🌅", "☀️", "🌙"]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text(isEditing ? "Edit group" : "New group")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(AppFont.titleTracking)
                    .foregroundStyle(palette.textPrimary)

                HStack(spacing: 10) {
                    TextField("", text: $emoji)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 22))
                        .frame(width: 56, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                                .fill(palette.surfaceAlt)
                        )
                        .onChange(of: emoji) { _, newValue in
                            if let last = newValue.last {
                                let s = String(last)
                                if s != emoji { emoji = s }
                            } else if !newValue.isEmpty {
                                emoji = ""
                            }
                        }

                    TextField("Group name", text: $title, axis: .vertical)
                        .font(AppFont.body)
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1...2)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                                .fill(palette.surfaceAlt)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Reminder time")
                    .font(AppFont.caption)
                    .tracking(0.6)
                    .foregroundStyle(palette.textSecondary)
                reminderTimeRow
            }

            recurrenceRow
            durationRow
            energyRow

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
                    .accessibilityLabel("Delete group")
                }

                Button(action: save) {
                    Text(isEditing ? "Save changes" : "Add group")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.onEnergy)
                        .frame(maxWidth: .infinity, minHeight: Geometry.minTapTarget)
                        .background(
                            RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                                .fill(canSave ? palette.energySteady : palette.surfaceAlt)
                        )
                }
                .buttonStyle(.pressable)
                .disabled(!canSave)
            }
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 24)
        .presentationDetents([.fraction(0.7), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Geometry.sheetRadius)
        .presentationBackground(palette.surface)
        .onAppear { seedIfNeeded() }
        .alert("Delete group?", isPresented: $showDeleteConfirm, presenting: group) { g in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { performDelete(g) }
        } message: { g in
            Text("Every routine in \u{201C}\(g.title)\u{201D} will stop repeating.")
        }
    }

    // MARK: - Rows

    private var reminderTimeRow: some View {
        HStack(spacing: 12) {
            Image(systemName: slotIconName(slot))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.textSecondary)
                .frame(width: 22)
            Text(slotLabel(slot))
                .font(AppFont.body)
                .foregroundStyle(palette.textPrimary)
            Spacer()
            DatePicker(
                "",
                selection: $reminderTime,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .tint(palette.energySteady)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                .fill(palette.surfaceAlt)
        )
        .onChange(of: reminderTime) { _, newValue in
            updateSlotAndEmoji(for: newValue)
        }
    }

    private var recurrenceRow: some View {
        Menu {
            ForEach(Recurrence.allCases.filter { $0 != .none }) { option in
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
                    .foregroundStyle(palette.textSecondary)
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

    private var durationRow: some View {
        Menu {
            ForEach(Self.durationPresets, id: \.self) { minutes in
                Button {
                    durationMinutes = minutes
                } label: {
                    if minutes == durationMinutes {
                        Label("\(minutes) min", systemImage: "checkmark")
                    } else {
                        Text("\(minutes) min")
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 22)
                Text("Time to complete")
                    .font(AppFont.body)
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("\(durationMinutes) min")
                    .font(AppFont.body)
                    .foregroundStyle(palette.textSecondary)
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

    private var energyRow: some View {
        Menu {
            Button {
                energy = nil
            } label: {
                if energy == nil {
                    Label("No energy tag", systemImage: "checkmark")
                } else {
                    Text("No energy tag")
                }
            }
            ForEach(EnergyLevel.taskAssignable, id: \.self) { level in
                Button {
                    energy = level
                } label: {
                    if energy == level {
                        Label(level.shortLabel, systemImage: "checkmark")
                    } else {
                        Text(level.shortLabel)
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bolt.heart")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 22)
                Text("Energy")
                    .font(AppFont.body)
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text(energy?.shortLabel ?? "Optional")
                    .font(AppFont.body)
                    .foregroundStyle(energy == nil ? palette.textDimmed : palette.textSecondary)
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

    /// Recompute the derived slot from the picked time, and refresh the
    /// default emoji *only* if the user hasn't already typed their own.
    private func updateSlotAndEmoji(for date: Date) {
        let hour = Calendar.current.component(.hour, from: date)
        let newSlot = RoutineSlot.from(hour: hour)
        slot = newSlot
        if emoji.isEmpty || Self.timeEmojis.contains(emoji) {
            emoji = newSlot.defaultEmoji
        }
    }

    private func slotIconName(_ s: RoutineSlot) -> String {
        switch s {
        case .morning:   return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening:   return "moon.fill"
        }
    }

    private func slotLabel(_ s: RoutineSlot) -> String {
        switch s {
        case .morning:   return "Morning"
        case .afternoon: return "Afternoon"
        case .evening:   return "Evening"
        }
    }

    // MARK: - State + save/delete

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func seedIfNeeded() {
        guard !didSeed else { return }
        let calendar = Calendar.current
        if let group {
            title = group.title
            emoji = group.emoji ?? ""
            slot = group.slot
            recurrence = group.recurrence
            energy = group.energy
            durationMinutes = max(group.runDurationSeconds / 60, 1)
            // Rehydrate the time picker from stored hour/minute if present;
            // otherwise fall back to the slot's legacy default hour.
            let hour = group.reminderHour ?? defaultHourForLegacy(slot: group.slot)
            let minute = group.reminderMinute ?? 0
            reminderTime = calendar.date(
                bySettingHour: hour, minute: minute, second: 0, of: Date()
            ) ?? Date()
        } else {
            slot = defaultSlot
            recurrence = .daily
            reminderTime = calendar.date(
                bySettingHour: defaultHourForLegacy(slot: defaultSlot),
                minute: 0, second: 0, of: Date()
            ) ?? Date()
            // Seed a time-appropriate emoji so the user has something
            // sensible without having to type one.
            emoji = defaultSlot.defaultEmoji
        }
        didSeed = true
    }

    /// Mirrors `RoutineScheduler.defaultHour` for legacy groups that don't
    /// have a `reminderHour` stored yet.
    private func defaultHourForLegacy(slot: RoutineSlot) -> Int {
        switch slot {
        case .morning:   return 8
        case .afternoon: return 13
        case .evening:   return 20
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalizedEmoji = emoji.isEmpty ? nil : emoji
        let normalizedRecurrence = recurrence == .none ? .daily : recurrence
        let calendar = Calendar.current
        let pickedHour = calendar.component(.hour, from: reminderTime)
        let pickedMinute = calendar.component(.minute, from: reminderTime)

        let durationSeconds = max(durationMinutes, 1) * 60

        if let group {
            group.title = trimmed
            group.emoji = normalizedEmoji
            group.slot = slot
            group.recurrence = normalizedRecurrence
            group.energy = energy
            group.reminderHour = pickedHour
            group.reminderMinute = pickedMinute
            group.totalDurationSeconds = durationSeconds
        } else {
            let userID = AuthManager.shared.currentUserID
            let g = RoutineGroup(
                title: trimmed,
                emoji: normalizedEmoji,
                slot: slot,
                recurrence: normalizedRecurrence,
                energy: energy,
                userID: userID,
                reminderHour: pickedHour,
                reminderMinute: pickedMinute,
                totalDurationSeconds: durationSeconds
            )
            context.insert(g)
            // No materialize call here — an empty group has no items to
            // materialize. Adding routines inside the group will trigger
            // the next pass on the user's next foreground.
        }
        context.saveAndSync()
        NotificationManager.refreshAllRoutineReminders(context: context)
        dismiss()
    }

    private func performDelete(_ g: RoutineGroup) {
        let groupID = g.id
        let tagDescriptor = FetchDescriptor<RoutineTag>(predicate: #Predicate { $0.groupID == groupID })
        let tags = (try? context.fetch(tagDescriptor)) ?? []
        let tagIDs = Set(tags.map(\.id))

        let allTasks = (try? context.fetch(FetchDescriptor<Task>())) ?? []
        let derived = allTasks.filter { t in
            t.sourceRoutineID.map { tagIDs.contains($0) } ?? false
        }
        for t in derived {
            SyncEngine.shared.deleteRemote(Task.self, id: t.id)
            context.delete(t)
        }
        for tag in tags { context.delete(tag) }
        context.delete(g)
        context.saveAndSync()
        NotificationManager.refreshAllRoutineReminders(context: context)
        dismiss()
    }
}
