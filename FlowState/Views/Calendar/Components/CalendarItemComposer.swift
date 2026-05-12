import SwiftUI

/// Inline composer for adding a task scoped to a time slot on the Calendar tab.
/// Pinned via `safeAreaInset(.bottom)` so it auto-rises above the keyboard.
struct CalendarItemComposer: View {
    @Binding var slot: DayTimeSlot
    @Binding var title: String
    @Binding var energyOverride: EnergyLevel?
    @Binding var recurrence: Recurrence
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @Environment(\.palette) private var palette
    @FocusState private var titleFocused: Bool
    @State private var speech = SpeechRecognizer()
    @State private var lastSpokenSync: String = ""

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Effective energy: user override wins; otherwise we suggest one from the title.
    private var effectiveEnergy: EnergyLevel {
        energyOverride ?? EventEnergyClassifier.heuristic(for: title)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            titleField
            chipsRow
            if let err = speech.lastError {
                Text(err)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.energyScattered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.surface)
                .shadow(color: palette.cardShadow, radius: 18, y: -4)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .onAppear { titleFocused = true }
        .onDisappear {
            _Concurrency.Task { await speech.stop() }
        }
        .onChange(of: speech.transcript) { _, newValue in
            // Update the title binding whenever the speech recognizer pushes a new transcript.
            // We track the last value we synced so we don't fight a user manually editing.
            guard speech.isRecording else { return }
            if newValue != lastSpokenSync {
                title = newValue
                lastSpokenSync = newValue
            }
        }
    }

    // MARK: - Title input

    private var titleField: some View {
        HStack(spacing: 0) {
            TextField("", text: $title, prompt:
                Text("What's next?")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(palette.textDimmed)
            )
            .focused($titleFocused)
            .font(.system(size: 22, weight: .regular, design: .serif))
            .foregroundStyle(palette.textPrimary)
            .submitLabel(.done)
            .onSubmit {
                if canSubmit { onSubmit() }
            }
            Spacer(minLength: 8)

            if !title.isEmpty {
                Button {
                    title = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(palette.textDimmed)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Clear")
            }
        }
    }

    // MARK: - Chips row

    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                slotChip
                energyChip
                recurrenceChip
                moreChip
                Spacer(minLength: 12)
                speakButton
            }
            .padding(.trailing, 4)
        }
    }

    private var slotChip: some View {
        Menu {
            ForEach(DayTimeSlot.allCases) { option in
                Button {
                    slot = option
                } label: {
                    Label(option.title, systemImage: option.iconName)
                }
            }
        } label: {
            chipLabel(icon: slot.iconName, text: slot.title.uppercased())
        }
        .accessibilityLabel("Time slot: \(slot.title)")
    }

    private var energyChip: some View {
        Menu {
            ForEach(EnergyLevel.taskAssignable, id: \.self) { level in
                Button {
                    energyOverride = level
                } label: {
                    Label(level.shortLabel, systemImage: level.iconName)
                }
            }
            Divider()
            Button {
                energyOverride = nil  // back to auto/heuristic
            } label: {
                Label("Auto", systemImage: "sparkles")
            }
        } label: {
            chipLabel(
                icon: effectiveEnergy.iconName,
                text: effectiveEnergy.shortLabel.uppercased(),
                tint: effectiveEnergy.color(in: palette).opacity(0.25)
            )
        }
        .accessibilityLabel("Energy: \(effectiveEnergy.shortLabel)")
    }

    private var recurrenceChip: some View {
        Menu {
            ForEach(Recurrence.allCases) { option in
                Button {
                    recurrence = option
                } label: {
                    Label(option.menuLabel, systemImage: option.iconName)
                }
            }
        } label: {
            chipLabel(icon: recurrence.iconName, text: recurrence.chipLabel.uppercased())
        }
        .accessibilityLabel("Recurrence: \(recurrence.menuLabel)")
    }

    private var moreChip: some View {
        Menu {
            Button {
                title = ""
            } label: {
                Label("Clear text", systemImage: "xmark")
            }
            .disabled(title.isEmpty)

            Button(role: .destructive) {
                onCancel()
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(palette.textPrimary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(palette.surfaceAlt))
        }
        .accessibilityLabel("More options")
    }

    private var speakButton: some View {
        Button {
            toggleSpeech()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: speech.isRecording ? "stop.circle.fill" : "waveform")
                    .font(.system(size: 12, weight: .bold))
                Text(speech.isRecording ? "Stop" : "Speak")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(speech.isRecording ? palette.onEnergy : palette.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(speech.isRecording ? palette.energyScattered : palette.surface)
            )
            .overlay(
                Capsule().stroke(palette.border, lineWidth: speech.isRecording ? 0 : 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(speech.isRecording ? "Stop recording" : "Speak")
    }

    private func chipLabel(icon: String, text: String, tint: Color? = nil) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .lineLimit(1)
        }
        .foregroundStyle(palette.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(tint ?? palette.surfaceAlt))
    }

    // MARK: - Speech

    private func toggleSpeech() {
        if speech.isRecording {
            _Concurrency.Task { await speech.stop() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                titleFocused = true
            }
        } else {
            // Hide keyboard while we listen so the recording UI is visible.
            titleFocused = false
            let seed = title
            lastSpokenSync = seed
            _Concurrency.Task {
                let started = await speech.start(seedText: seed)
                if !started {
                    // Re-focus the field so the user can fall back to typing.
                    await MainActor.run { titleFocused = true }
                }
            }
        }
    }
}
