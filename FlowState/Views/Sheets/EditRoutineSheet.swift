import SwiftUI
import SwiftData

/// Editor for a `RoutineTag` (label, emoji, slot). Mirrors `AddTaskSheet`'s
/// dual create/edit shape: when `routine` is non-nil the sheet edits in
/// place; when nil it inserts a new routine in `defaultSlot`.
///
/// In edit mode, saving also rewrites today's materialized task and
/// reschedules it if the slot changed. In create mode, after inserting the
/// new `RoutineTag` we run `RoutineScheduler.materializeToday` so today's
/// instance appears immediately without waiting for the next app
/// foreground.
struct EditRoutineSheet: View {
    var routine: RoutineTag? = nil
    var defaultSlot: RoutineSlot = .morning
    /// When inserting a new routine from inside a group's "Add routine"
    /// action, this is the parent group. The new tag carries `groupID =
    /// group.id`; the slot is also inherited from the group.
    var defaultGroup: RoutineGroup? = nil
    /// The materialized routine `Task` for today, if any. Only used in edit
    /// mode so the home list reflects label/slot changes immediately.
    var materializedToday: Task? = nil

    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var label: String = ""
    @State private var emoji: String = ""
    @State private var slot: RoutineSlot = .morning
    @State private var didSeed: Bool = false

    private var isEditing: Bool { routine != nil }

    private static let defaultHour: [RoutineSlot: Int] = [
        .morning: 8, .afternoon: 13, .evening: 20
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text(isEditing ? "Edit routine" : "New routine")
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
                            // Keep a single character/emoji. Picks the last
                            // character entered so the field always reflects
                            // the latest tap.
                            if let last = newValue.last {
                                let s = String(last)
                                if s != emoji { emoji = s }
                            } else if !newValue.isEmpty {
                                emoji = ""
                            }
                        }

                    TextField("Routine name", text: $label, axis: .vertical)
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

            Spacer(minLength: 0)

            Button(action: save) {
                Text(isEditing ? "Save changes" : "Add routine")
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
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 24)
        .presentationDetents([.fraction(0.5), .medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Geometry.sheetRadius)
        .presentationBackground(palette.surface)
        .onAppear { seedIfNeeded() }
    }

    private func seedIfNeeded() {
        guard !didSeed else { return }
        if let routine {
            label = routine.label
            emoji = routine.emoji
            slot = routine.slot
        } else if let defaultGroup {
            slot = defaultGroup.slot
        } else {
            slot = defaultSlot
        }
        didSeed = true
    }

    private func slotChip(_ s: RoutineSlot) -> some View {
        let on = slot == s
        return Button {
            slot = s
        } label: {
            HStack(spacing: 6) {
                Image(systemName: slotIcon(s))
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

    private func slotIcon(_ s: RoutineSlot) -> String {
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

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !emoji.isEmpty
    }

    private func save() {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !emoji.isEmpty else { return }

        if let routine {
            let slotChanged = routine.slot != slot
            routine.label = trimmed
            routine.emoji = emoji
            routine.slot = slot

            if let task = materializedToday {
                task.title = "\(emoji) \(trimmed)"
                task.routineSlot = slot.rawValue
                if slotChanged, let s = task.scheduledDate {
                    let cal = Calendar.current
                    let hour = Self.defaultHour[slot] ?? 8
                    task.scheduledDate = cal.date(
                        bySettingHour: hour, minute: 0, second: 0, of: cal.startOfDay(for: s)
                    ) ?? s
                }
                task.markDirty()
            }
            context.saveAndSync()
        } else {
            let userID = AuthManager.shared.currentUserID
            let tag = RoutineTag(
                emoji: emoji,
                label: trimmed,
                slot: slot,
                userID: userID,
                groupID: defaultGroup?.id
            )
            context.insert(tag)
            context.saveAndSync()
            // Bring today's instance into existence right away so the home
            // list reflects the new routine without a foreground.
            RoutineScheduler.materializeToday(context: context, userID: userID)
        }

        dismiss()
    }
}
