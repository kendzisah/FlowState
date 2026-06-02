import SwiftUI
import SwiftData

/// Brain-dump chat. User types or speaks a flat list; OpenAI extracts discrete
/// tasks with energy hints, user picks which ones to add, they land on today's
/// task board (scheduledDate = today's anytime slot).
///
/// Reuses `TaskExtractor.extract(from:)` (built for onboarding S15-S17) and
/// `SpeechRecognizer` (built for the calendar composer's Speak button).
struct ChatTabView: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext

    @State private var turns: [ChatTurn] = []
    @State private var draft: String = ""
    @State private var isThinking: Bool = false
    @State private var speech = SpeechRecognizer()
    @State private var lastSpokenSync: String = ""
    @FocusState private var inputFocused: Bool

    private var quota: AIQuotaState { AIQuotaState.shared }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            messageList
            inputBar
        }
        .background(Color.clear)
        .firstTimeTooltip(
            id: "chat.brainDump",
            title: "Talk it out",
            body: "Type or dictate what's on your mind. FlowState sorts your dump into tasks, tags them by energy, and adds them to your list."
        )
        .onChange(of: speech.transcript) { _, newValue in
            guard speech.isRecording, newValue != lastSpokenSync else { return }
            draft = newValue
            lastSpokenSync = newValue
        }
        .onDisappear {
            _Concurrency.Task { await speech.stop() }
        }
        .task {
            // Tick every 30s so the lock automatically lifts at the reset time
            // without requiring a fresh send. Cheap: just checks the cached date.
            while !_Concurrency.Task.isCancelled {
                quota.clearIfExpired()
                try? await _Concurrency.Task.sleep(for: .seconds(30))
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Brain dump")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                Text("Tell me what's on your mind. I'll sort it.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer()
            if !turns.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        turns.removeAll()
                    }
                } label: {
                    Text("Clear")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.vertical, 12)
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if turns.isEmpty {
                        emptyState
                    } else {
                        ForEach(turns) { turn in
                            ChatTurnView(
                                turn: turn,
                                onToggle: { taskID in toggleSelection(turnID: turn.id, taskID: taskID) },
                                onAdd: { addTasks(forTurnID: turn.id) }
                            )
                            .id(turn.id)
                        }
                    }
                }
                .padding(.horizontal, Geometry.horizontalPadding)
                .padding(.vertical, 16)
            }
            .onChange(of: turns.count) { _, _ in
                if let last = turns.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer().frame(height: 24)
            FoggyMascot(size: 56, animated: true)
                .frame(maxWidth: .infinity)
            Text("Try saying:")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(palette.textDimmed)
                .padding(.top, 8)
            ForEach([
                "Email Sarah about Tuesday, gym at 6, prep the slides",
                "Pick up groceries, call dentist, finish deep-work block",
                "Do laundry, water plants, draft the doc"
            ], id: \.self) { example in
                Text("\u{201C}\(example)\u{201D}")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(palette.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(palette.surface)
                    )
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.4)
            if quota.isLocked {
                quotaLockedBanner
            }
            HStack(alignment: .bottom, spacing: 8) {
                inputField
                actionButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .opacity(quota.isLocked ? 0.5 : 1)
            .allowsHitTesting(!quota.isLocked)
            if shouldShowCharacterCount && !quota.isLocked {
                HStack {
                    Spacer()
                    characterCountLabel
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
            if let err = speech.lastError, !quota.isLocked {
                Text(err)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.energyScattered)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }
        }
        .background(palette.surface)
    }

    private var quotaLockedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(palette.energyScattered)
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily AI limit reached")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Text("Try again \(quota.formattedResetTime()).")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(palette.energyScattered.opacity(0.08))
        .overlay(
            Rectangle()
                .fill(palette.energyScattered.opacity(0.35))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var inputField: some View {
        ZStack(alignment: .topLeading) {
            if draft.isEmpty {
                Text("What's on your plate?")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(palette.textDimmed)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $draft)
                .focused($inputFocused)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(minHeight: 40, maxHeight: 120)
                .foregroundStyle(palette.textPrimary)
                .font(.system(size: 15))
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.surfaceAlt)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.border, lineWidth: 1)
                )
        )
    }

    private enum InputAction { case mic, stop, send }

    private var currentAction: InputAction {
        if speech.isRecording { return .stop }
        if canSend { return .send }
        return .mic
    }

    private var actionButton: some View {
        Button {
            switch currentAction {
            case .mic, .stop: toggleSpeech()
            case .send: send()
            }
        } label: {
            Image(systemName: actionIcon)
                .font(.system(size: currentAction == .mic ? 16 : 15,
                              weight: currentAction == .mic ? .semibold : .bold))
                .foregroundStyle(currentAction == .mic ? palette.textPrimary : palette.onEnergy)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 40, height: 40)
                .background(Circle().fill(actionFill))
                .overlay(
                    Circle().stroke(palette.border,
                                    lineWidth: currentAction == .mic ? 1 : 0)
                )
        }
        .buttonStyle(.pressable)
        .disabled(currentAction == .send && isThinking)
        .accessibilityLabel(actionLabel)
        .animation(.easeInOut(duration: 0.18), value: currentAction)
    }

    private var actionIcon: String {
        switch currentAction {
        case .mic: return "mic.fill"
        case .stop: return "stop.fill"
        case .send: return "arrow.up"
        }
    }

    private var actionFill: Color {
        switch currentAction {
        case .mic: return palette.surfaceAlt
        case .stop: return palette.energyScattered
        case .send: return palette.energySteady
        }
    }

    private var actionLabel: String {
        switch currentAction {
        case .mic: return "Speak"
        case .stop: return "Stop recording"
        case .send: return "Send"
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.count <= OpenAIClient.maxUserPromptCharacters
    }

    /// True once the user has typed enough to warrant showing the counter.
    /// The threshold (80% of the cap) keeps the UI quiet for normal use
    /// and only nudges when overflow becomes a real risk.
    private var shouldShowCharacterCount: Bool {
        draft.count > Int(Double(OpenAIClient.maxUserPromptCharacters) * 0.8)
    }

    private var isOverCharacterLimit: Bool {
        draft.count > OpenAIClient.maxUserPromptCharacters
    }

    @ViewBuilder
    private var characterCountLabel: some View {
        if shouldShowCharacterCount {
            Text("\(draft.count) / \(OpenAIClient.maxUserPromptCharacters)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(isOverCharacterLimit ? palette.energyScattered : palette.textSecondary)
                .accessibilityLabel(
                    isOverCharacterLimit
                        ? "Over the \(OpenAIClient.maxUserPromptCharacters) character limit"
                        : "\(draft.count) of \(OpenAIClient.maxUserPromptCharacters) characters"
                )
        }
    }

    // MARK: - Actions

    private func toggleSpeech() {
        if quota.isLocked { return }
        if speech.isRecording {
            _Concurrency.Task { await speech.stop() }
        } else {
            inputFocused = false
            lastSpokenSync = draft
            _Concurrency.Task {
                let ok = await speech.start(seedText: draft)
                if !ok {
                    await MainActor.run { inputFocused = true }
                }
            }
        }
    }

    private func send() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !quota.isLocked else { return }

        if speech.isRecording {
            _Concurrency.Task { await speech.stop() }
        }

        let userTurnID = UUID()
        let thinkingTurnID = UUID()
        turns.append(.userMessage(id: userTurnID, text: trimmed))
        turns.append(.thinking(id: thinkingTurnID))
        draft = ""
        lastSpokenSync = ""
        isThinking = true

        _Concurrency.Task {
            do {
                let extracted = try await TaskExtractor.extract(from: trimmed)
                await MainActor.run {
                    isThinking = false
                    turns.removeAll { $0.id == thinkingTurnID }
                    if extracted.isEmpty {
                        turns.append(.error(id: UUID(),
                            message: "I couldn't pull tasks out of that. Try listing things separated by commas or new lines."))
                    } else {
                        turns.append(.extracted(
                            id: UUID(),
                            tasks: extracted,
                            selected: Set(extracted.map(\.id)),
                            added: false
                        ))
                    }
                }
            } catch OpenAIClientError.quotaExceeded {
                AnalyticsErrorReporter.reportMessage("chat quota", context: "chat.quota", level: "warning")
                await MainActor.run {
                    isThinking = false
                    turns.removeAll { $0.id == thinkingTurnID }
                    turns.append(.error(id: UUID(),
                        message: "Daily AI limit reached. Try again \(quota.formattedResetTime())."))
                }
            } catch OpenAIClientError.inputTooLong(let limit, let given) {
                // Client-side reject. No quota consumed. Friendly message
                // tells the user how much to trim.
                await MainActor.run {
                    isThinking = false
                    turns.removeAll { $0.id == thinkingTurnID }
                    turns.append(.error(id: UUID(),
                        message: "That's a lot to take in at once (\(given) characters). Try breaking it into \(limit) characters or fewer."))
                }
            } catch {
                AnalyticsErrorReporter.report(error, context: "chat.command")
                await MainActor.run {
                    isThinking = false
                    turns.removeAll { $0.id == thinkingTurnID }
                    turns.append(.error(id: UUID(),
                        message: "Something went wrong. Try again in a moment."))
                }
            }
        }
    }

    private func toggleSelection(turnID: UUID, taskID: UUID) {
        guard let idx = turns.firstIndex(where: { $0.id == turnID }) else { return }
        if case .extracted(let id, let tasks, var selected, let added) = turns[idx], !added {
            if selected.contains(taskID) {
                selected.remove(taskID)
            } else {
                selected.insert(taskID)
            }
            turns[idx] = .extracted(id: id, tasks: tasks, selected: selected, added: added)
        }
    }

    private func addTasks(forTurnID turnID: UUID) {
        guard let idx = turns.firstIndex(where: { $0.id == turnID }) else { return }
        if case .extracted(let id, let tasks, let selected, false) = turns[idx] {
            let chosen = tasks.filter { selected.contains($0.id) }
            guard !chosen.isEmpty else { return }

            let anytimeToday = Calendar.current.startOfDay(for: Date())
            for draft in chosen {
                let raw = draft.suggestedEnergyRaw.lowercased()
                let energy: EnergyLevel = {
                    if let parsed = EnergyLevel(rawValue: raw),
                       EnergyLevel.taskAssignable.contains(parsed) {
                        return parsed
                    }
                    return .steady
                }()
                let task = Task(title: draft.title, energyTag: energy)
                task.scheduledDate = anytimeToday
                modelContext.insert(task)
            }
            modelContext.saveAndSync()

            // Mark the bubble as added so checkboxes lock and Add button hides.
            turns[idx] = .extracted(id: id, tasks: tasks, selected: selected, added: true)
            turns.append(.confirmation(
                id: UUID(),
                message: "Added \(chosen.count) task\(chosen.count == 1 ? "" : "s") to today."
            ))
        }
    }
}

// MARK: - Turn types

enum ChatTurn: Identifiable {
    case userMessage(id: UUID, text: String)
    case thinking(id: UUID)
    case extracted(id: UUID, tasks: [DraftTask], selected: Set<UUID>, added: Bool)
    case confirmation(id: UUID, message: String)
    case error(id: UUID, message: String)

    var id: UUID {
        switch self {
        case .userMessage(let id, _),
             .thinking(let id),
             .extracted(let id, _, _, _),
             .confirmation(let id, _),
             .error(let id, _):
            return id
        }
    }
}

// MARK: - Turn rendering

private struct ChatTurnView: View {
    let turn: ChatTurn
    let onToggle: (UUID) -> Void
    let onAdd: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        switch turn {
        case .userMessage(_, let text):
            HStack {
                Spacer(minLength: 40)
                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(palette.onEnergy)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(palette.energySteady)
                    )
            }

        case .thinking:
            HStack {
                ThinkingBubble()
                Spacer(minLength: 40)
            }

        case .extracted(_, let tasks, let selected, let added):
            HStack(alignment: .top) {
                ExtractedTasksBubble(
                    tasks: tasks,
                    selected: selected,
                    added: added,
                    onToggle: onToggle,
                    onAdd: onAdd
                )
                Spacer(minLength: 40)
            }

        case .confirmation(_, let message):
            HStack {
                Text(message)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(palette.surface))
                Spacer()
            }

        case .error(_, let message):
            HStack {
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.energyScattered)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(palette.surface)
                    )
                Spacer(minLength: 40)
            }
        }
    }
}

private struct ThinkingBubble: View {
    @Environment(\.palette) private var palette
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(palette.textSecondary)
                    .frame(width: 6, height: 6)
                    .opacity(phase == i ? 1.0 : 0.35)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.surface)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: false)) {
                phase = (phase + 1) % 3
            }
            _Concurrency.Task {
                while !_Concurrency.Task.isCancelled {
                    try? await _Concurrency.Task.sleep(nanoseconds: 400_000_000)
                    await MainActor.run { phase = (phase + 1) % 3 }
                }
            }
        }
    }
}

private struct ExtractedTasksBubble: View {
    let tasks: [DraftTask]
    let selected: Set<UUID>
    let added: Bool
    let onToggle: (UUID) -> Void
    let onAdd: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(added ? "Added these to your day:" : "Pick the ones you want today:")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.textSecondary)

            VStack(spacing: 6) {
                ForEach(tasks) { task in
                    row(for: task)
                }
            }

            if !added {
                Button(action: onAdd) {
                    Text("Add \(selected.count) task\(selected.count == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(palette.onEnergy)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(
                            Capsule().fill(selected.isEmpty ? palette.surfaceAlt : palette.energySteady)
                        )
                }
                .buttonStyle(.pressable)
                .disabled(selected.isEmpty)
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.surface)
        )
    }

    private func row(for task: DraftTask) -> some View {
        let isSelected = selected.contains(task.id)
        let energy = task.suggestedEnergy ?? .steady
        return Button {
            if !added { onToggle(task.id) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? palette.energySteady : palette.textDimmed)
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 6)
                HStack(spacing: 4) {
                    Image(systemName: energy.iconName)
                        .font(.system(size: 9, weight: .bold))
                    Text(energy.shortLabel.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.6)
                }
                .foregroundStyle(palette.onEnergy)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(energy.color(in: palette)))
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.pressable)
        .disabled(added)
        .opacity(added && !isSelected ? 0.4 : 1.0)
    }
}
