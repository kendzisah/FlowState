import SwiftUI

/// Compact day navigator for the Schedule tab: prev/next-day arrows plus a
/// tappable date that opens the month picker. Replaces the old serif day-name
/// header and the `S M T W T F S` week strip.
struct DayNavBar: View {
    @Binding var selectedDate: Date
    let onPickDate: () -> Void

    @Environment(\.palette) private var palette
    private let calendar = Calendar.current

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: selectedDate)
    }

    private var isToday: Bool { calendar.isDateInToday(selectedDate) }

    var body: some View {
        HStack(spacing: 10) {
            arrow("chevron.left", label: "Previous day", delta: -1)

            Button(action: onPickDate) {
                HStack(spacing: 6) {
                    Text(dateLabel)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(palette.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("\(dateLabel). Tap to pick a day.")

            Spacer(minLength: 0)

            if !isToday {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { selectedDate = Date() }
                } label: {
                    Text("Today")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.energySteady)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Jump to today")
            }

            arrow("chevron.right", label: "Next day", delta: 1)
        }
    }

    private func arrow(_ icon: String, label: String, delta: Int) -> some View {
        Button {
            if let d = calendar.date(byAdding: .day, value: delta, to: selectedDate) {
                withAnimation(.easeOut(duration: 0.2)) { selectedDate = d }
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(palette.textPrimary)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(palette.surface)
                        .overlay(Circle().stroke(palette.border, lineWidth: 1))
                )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
    }
}
