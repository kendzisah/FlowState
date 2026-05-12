import SwiftUI

struct DayHeaderView: View {
    let date: Date
    let onMonthTap: () -> Void

    @Environment(\.palette) private var palette

    private var dayName: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    private var monthYearLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: date).uppercased()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(dayName)
                .font(.system(size: 36, weight: .bold, design: .serif))
                .tracking(-0.5)
                .foregroundStyle(palette.textPrimary)
            Spacer()
            Button(action: onMonthTap) {
                HStack(spacing: 4) {
                    Text(monthYearLabel)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(palette.textSecondary)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Pick month and year")
        }
    }
}
