import SwiftUI
import SwiftData

struct TimerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context

    var body: some View {
        @Bindable var bindable = store

        VStack(spacing: 22) {
            Spacer(minLength: 8)

            VStack(spacing: 8) {
                Text(store.activeTask?.title ?? "")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, Geometry.horizontalPadding)

                Text(AppStrings.timerFocusLabel)
                    .font(AppFont.caption)
                    .tracking(1.6)
                    .foregroundStyle(palette.textSecondary)
            }

            DurationChip(mode: store.timerMode, totalSeconds: store.timerDurationSeconds) {
                store.showDurationPicker = true
            }

            CircularTimer(
                mode: store.timerMode,
                secondsRemaining: store.timerSecondsRemaining,
                secondsElapsed: store.timerElapsedSeconds,
                totalSeconds: store.timerDurationSeconds,
                arcColor: (store.energyLevel ?? .steady).color(in: palette)
            )
            .padding(.vertical, 8)

            Spacer(minLength: 8)

            VStack(spacing: 12) {
                Text(AppStrings.timerHijackPrompt)
                    .font(AppFont.caption)
                    .foregroundStyle(palette.textDimmed)

                Button {
                    store.parkTask(context: context)
                } label: {
                    Text(AppStrings.timerParkAction)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: Geometry.minTapTarget)
                        .background(
                            RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                                .fill(palette.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                                        .stroke(palette.border, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.pressable)

                Button {
                    if let task = store.activeTask {
                        store.completeTask(task, context: context)
                    }
                } label: {
                    Text(AppStrings.timerDoneAction)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.onEnergy)
                        .frame(maxWidth: .infinity, minHeight: Geometry.minTapTarget)
                        .background(
                            RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                                .fill((store.energyLevel ?? .steady).color(in: palette))
                        )
                }
                .buttonStyle(.pressable)
            }
            .padding(.horizontal, Geometry.horizontalPadding)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $bindable.showDurationPicker) {
            DurationPickerSheet()
                .environment(\.palette, palette)
        }
        .firstTimeTooltip(
            id: "timer.flow",
            title: "Quiet focus",
            body: "Tap the duration to change it. Park the task to come back later — it goes to your parked list, not the bin. Complete to log it and clear the screen."
        )
    }
}
