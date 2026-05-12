import SwiftUI

/// Half-modal month picker. Tapping any day jumps the Calendar tab to that day,
/// so the user can browse other months and add tasks via the existing slot composer.
struct MonthPickerSheet: View {
    @Binding var selectedDate: Date
    let onClose: () -> Void

    @Environment(\.palette) private var palette
    @State private var pickerDate: Date

    init(selectedDate: Binding<Date>, onClose: @escaping () -> Void) {
        self._selectedDate = selectedDate
        self.onClose = onClose
        self._pickerDate = State(initialValue: selectedDate.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    pickerDate = Date()
                } label: {
                    Text("Today")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.energySteady)
                }

                Spacer()

                Text("Pick a day")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)

                Spacer()

                Button {
                    selectedDate = pickerDate
                    onClose()
                } label: {
                    Text("Done")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            DatePicker(
                "Pick day",
                selection: $pickerDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .tint(palette.energySteady)
            .padding(.horizontal, 12)

            Spacer(minLength: 0)
        }
        .padding(.top, 16)
        .background(palette.surface)
    }
}
