import SwiftUI

struct DurationPickerSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    private var energyDefault: Int? {
        (store.energyLevel ?? .steady).defaultDurationSeconds
    }

    private var currentSeconds: Int? {
        store.timerMode == .countdown ? store.timerDurationSeconds : nil
    }

    private var finitePresets: [Int] {
        durationPresetsSeconds.compactMap { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(AppStrings.durationPickerTitle)
                    .font(AppFont.title)
                    .tracking(AppFont.titleTracking)
                    .foregroundStyle(palette.textPrimary)
                Text(AppStrings.durationPickerSubtitle)
                    .font(AppFont.body)
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(.top, 8)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(finitePresets, id: \.self) { secs in
                    chip(secs: secs)
                }
            }

            chip(secs: nil)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.bottom, 24)
        .presentationDetents([.fraction(0.55), .medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Geometry.sheetRadius)
        .presentationBackground(palette.surface)
    }

    private func chip(secs: Int?) -> some View {
        let isCurrent: Bool = {
            switch secs {
            case nil: return store.timerMode == .countup
            case let s?: return store.timerMode == .countdown && store.timerDurationSeconds == s
            }
        }()
        let isSuggested = secs == energyDefault

        let text: String = secs == nil
            ? AppStrings.durationNoCap
            : "\(secs! / 60) min"

        return Button {
            store.setTimerDuration(secs)
            dismiss()
        } label: {
            ZStack(alignment: .topTrailing) {
                HStack {
                    Spacer()
                    Text(text)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isCurrent ? palette.onEnergy : palette.textPrimary)
                    Spacer()
                }
                .frame(minHeight: Geometry.minTapTarget)
                .background(
                    RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                        .fill(isCurrent
                              ? (store.energyLevel ?? .steady).color(in: palette)
                              : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                        .stroke(palette.border, lineWidth: 1)
                )

                if isSuggested {
                    Text(AppStrings.durationPickerSuggested)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(isCurrent ? palette.onEnergy : palette.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .stroke(isCurrent ? palette.onEnergy : palette.textSecondary, lineWidth: 1)
                        )
                        .padding(8)
                }
            }
        }
        .buttonStyle(.pressable)
    }
}
