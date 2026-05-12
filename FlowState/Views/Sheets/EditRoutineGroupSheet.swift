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
    @State private var recurrence: Recurrence = .daily
    @State private var energy: EnergyLevel? = nil
    @State private var didSeed: Bool = false
    @State private var showDeleteConfirm: Bool = false

    private var isEditing: Bool { group != nil }

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
                Text("Time of day")
                    .font(AppFont.caption)
                    .tracking(0.6)
                    .foregroundStyle(palette.textSecondary)
                HStack(spacing: 10) {
                    ForEach(RoutineSlot.allCases, id: \.self) { s in
                        slotChip(s)
                    }
                }
            }

            recurrenceRow
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

    private func slotChip(_ s: RoutineSlot) -> some View {
        let on = slot == s
        return Button {
            slot = s
        } label: {
            HStack(spacing: 6) {
                Image(systemName: slotIconName(s))
                    .font(.system(size: 13, weight: .semibold))
                Text(slotLabel(s))
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(on ? palette.onEnergy : palette.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(Capsule().fill(on ? palette.energySteady : palette.surfaceAlt))
        }
        .buttonStyle(.pressable)
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
        if let group {
            title = group.title
            emoji = group.emoji ?? ""
            slot = group.slot
            recurrence = group.recurrence
            energy = group.energy
        } else {
            slot = defaultSlot
            recurrence = .daily
        }
        didSeed = true
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalizedEmoji = emoji.isEmpty ? nil : emoji
        let normalizedRecurrence = recurrence == .none ? .daily : recurrence

        if let group {
            group.title = trimmed
            group.emoji = normalizedEmoji
            group.slot = slot
            group.recurrence = normalizedRecurrence
            group.energy = energy
        } else {
            let userID = AuthManager.shared.currentUserID
            let g = RoutineGroup(
                title: trimmed,
                emoji: normalizedEmoji,
                slot: slot,
                recurrence: normalizedRecurrence,
                energy: energy,
                userID: userID
            )
            context.insert(g)
            // No materialize call here — an empty group has no items to
            // materialize. Adding routines inside the group will trigger
            // the next pass on the user's next foreground.
        }
        context.saveAndSync()
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
        dismiss()
    }
}
