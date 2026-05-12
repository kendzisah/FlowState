import SwiftUI
import SwiftData

struct ScheduleTaskSheet: View {
    @Bindable var task: Task
    let onClose: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @State private var pickerDate: Date

    init(task: Task, onClose: @escaping () -> Void) {
        self._task = Bindable(task)
        self.onClose = onClose

        // Default: existing scheduled date, else today at 9 AM (or now+1h, whichever is later).
        let calendar = Calendar.current
        let baseline: Date = task.scheduledDate ?? {
            let now = Date()
            let nineToday = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
            let inOneHour = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
            return max(nineToday, inOneHour)
        }()
        self._pickerDate = State(initialValue: baseline)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Schedule task")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
            }

            DatePicker(
                "Pick date and time",
                selection: $pickerDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .tint(palette.energySteady)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                if task.scheduledDate != nil {
                    Button(role: .destructive) {
                        task.scheduledDate = nil
                        modelContext.saveAndSync()
                        onClose()
                    } label: {
                        Text("Remove")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(palette.energyScattered)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(palette.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.pressable)
                }

                OnbPrimaryButton(title: "Save") {
                    task.scheduledDate = pickerDate
                    modelContext.saveAndSync()
                    onClose()
                }
            }
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }
}
