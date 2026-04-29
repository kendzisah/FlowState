import SwiftUI

enum TaskListTab: Hashable {
    case tasks, parked
}

struct BottomTabBar: View {
    @Binding var selected: TaskListTab
    let parkedCount: Int

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            tab(.tasks, label: AppStrings.tasksTabLabel, count: nil)
            tab(.parked, label: AppStrings.parkedTabLabel, count: parkedCount)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Geometry.pillRadius, style: .continuous)
                .fill(palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Geometry.pillRadius, style: .continuous)
                        .stroke(palette.border, lineWidth: 1)
                )
        )
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.bottom, 8)
    }

    private func tab(_ kind: TaskListTab, label: String, count: Int?) -> some View {
        let isOn = selected == kind
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { selected = kind }
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(palette.onEnergy)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(palette.energySteady))
                }
            }
            .foregroundStyle(isOn ? palette.textPrimary : palette.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                Capsule().fill(isOn ? palette.surfaceAlt : .clear)
            )
        }
        .buttonStyle(.pressable)
    }
}
