import SwiftUI

struct WeekStripView: View {
    @Binding var selectedDate: Date

    @Environment(\.palette) private var palette
    private let calendar = Calendar.current

    private var weekDays: [Date] {
        // Anchor on the week containing the selected date; weekStart based on user locale.
        let weekday = calendar.component(.weekday, from: selectedDate)
        let firstWeekday = calendar.firstWeekday
        let offsetToWeekStart = (weekday - firstWeekday + 7) % 7
        guard let weekStart = calendar.date(byAdding: .day, value: -offsetToWeekStart, to: calendar.startOfDay(for: selectedDate)) else {
            return [selectedDate]
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                DayCell(
                    date: day,
                    isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(day)
                )
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedDate = day
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(calendar.isDate(day, inSameDayAs: selectedDate) ? .isSelected : [])
            }
        }
    }
}

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool

    @Environment(\.palette) private var palette

    private var letter: String {
        let f = DateFormatter()
        f.dateFormat = "EEEEE"  // narrow day-of-week (S, M, T, W, T, F, S)
        return f.string(from: date)
    }

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: date))"
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(letter)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isSelected ? palette.textPrimary : palette.textDimmed)
            Text(dayNumber)
                .font(.system(size: 17, weight: isSelected || isToday ? .bold : .medium))
                .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)
                .frame(width: 36, height: 36)
                .background(
                    Capsule()
                        .fill(isSelected ? palette.surface : Color.clear)
                        .overlay(
                            Capsule()
                                .stroke(isToday && !isSelected ? palette.border : Color.clear, lineWidth: 1)
                        )
                )
        }
        .padding(.vertical, 4)
    }
}
