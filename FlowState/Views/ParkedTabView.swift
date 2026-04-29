import SwiftUI
import SwiftData

struct ParkedTabView: View {
    let parkedTasks: [ParkedTask]
    let allTasks: [Task]

    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context

    var body: some View {
        if parkedTasks.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "brain")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(palette.textDimmed)
                Text(AppStrings.parkedEmptyState)
                    .font(AppFont.body)
                    .foregroundStyle(palette.textSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(parkedTasks, id: \.id) { p in
                        ParkedRow(parked: p) {
                            store.resumeParked(p, allTasks: allTasks, context: context)
                        }
                    }
                }
                .padding(.horizontal, Geometry.horizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
        }
    }
}

private struct ParkedRow: View {
    let parked: ParkedTask
    var onResume: () -> Void

    @Environment(\.palette) private var palette
    private let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(parked.taskTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.parkedText)
                    .multilineTextAlignment(.leading)
                Text("Parked \(formatter.localizedString(for: parked.parkedAt, relativeTo: Date()))")
                    .font(AppFont.caption)
                    .foregroundStyle(palette.parkedMeta)
            }

            Spacer(minLength: 8)

            Button(action: onResume) {
                Text("Resume")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.onEnergy)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(palette.parkedAccent))
            }
            .buttonStyle(.pressable)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                .fill(palette.parkedBg)
        )
        .shadow(color: palette.cardShadow, radius: 6, x: 0, y: 2)
    }
}
