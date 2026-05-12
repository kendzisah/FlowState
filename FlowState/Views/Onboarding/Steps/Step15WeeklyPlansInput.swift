import SwiftUI

struct Step15WeeklyPlansInput: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void

    @Environment(\.palette) private var palette
    @State private var text: String = ""
    @FocusState private var inputFocused: Bool

    private struct Hint: Identifiable {
        let id = UUID()
        let emoji: String
        let label: String
    }
    private let hints: [Hint] = [
        .init(emoji: "📚", label: "Work or school"),
        .init(emoji: "✅", label: "To-dos and errands"),
        .init(emoji: "💜", label: "Social plans"),
        .init(emoji: "🏠", label: "Home & family")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer().frame(height: 70)

            FoggyMascot(size: 64)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("Any other plans this week?")
                .font(.system(size: 24, weight: .bold))
                .tracking(AppFont.titleTracking)
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(hints) { h in
                    HStack(spacing: 10) {
                        Text(h.emoji)
                            .font(.system(size: 18))
                        Text(h.label)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
            }

            Spacer()

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Type freely — e.g., 'Build apps, prep for Tuesday meeting, call dentist.'")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(palette.textDimmed)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .focused($inputFocused)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 48)
                    .frame(minHeight: 140, maxHeight: 200)
                    .foregroundStyle(palette.textPrimary)
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 10) {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 30, weight: .regular))
                            .foregroundStyle(text.isEmpty ? palette.textDimmed : palette.textSecondary)
                    }
                    .buttonStyle(.pressable)
                    .disabled(text.isEmpty)
                    .accessibilityLabel("Clear")

                    Button {
                        submit()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30, weight: .regular))
                            .foregroundStyle(canSubmit ? palette.energySteady : palette.textDimmed)
                    }
                    .buttonStyle(.pressable)
                    .disabled(!canSubmit)
                    .accessibilityLabel("Send")
                }
                .padding(10)
            }
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.bottom, 24)
        .onAppear { inputFocused = true }
    }

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard canSubmit else { return }
        draft.weeklyIntentText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        inputFocused = false
        onContinue()
    }
}
