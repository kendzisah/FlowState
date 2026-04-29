import SwiftUI

struct RestView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var palette

    @State private var microAction: String = AppStrings.foggyMicroActions.randomElement() ?? ""

    var body: some View {
        ZStack {
            FogLayer()

            VStack(spacing: 0) {
                HStack {
                    BatteryPill()
                    Spacer()
                }
                .padding(.horizontal, Geometry.horizontalPadding)
                .padding(.top, 12)

                Spacer(minLength: 24)

                VStack(spacing: 10) {
                    Text(AppStrings.restHeadline)
                        .font(AppFont.title)
                        .tracking(AppFont.titleTracking)
                        .foregroundStyle(palette.textPrimary)
                    Text(AppStrings.restSubhead)
                        .font(AppFont.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.textSecondary)
                }
                .padding(.horizontal, Geometry.horizontalPadding)

                Spacer(minLength: 24)

                MicroActionCard(text: microAction)
                    .padding(.horizontal, Geometry.horizontalPadding)

                Spacer(minLength: 24)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.peekList = true
                    }
                } label: {
                    Text(AppStrings.restPeekCTA)
                        .font(AppFont.body)
                        .underline()
                        .foregroundStyle(palette.textPrimary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 18)
                        .frame(minHeight: Geometry.minTapTarget)
                }
                .buttonStyle(.pressable)

                Text(AppStrings.restPeekFooter)
                    .font(AppFont.caption)
                    .foregroundStyle(palette.textDimmed)
                    .padding(.bottom, 32)
            }
        }
        .onAppear {
            microAction = AppStrings.foggyMicroActions.randomElement() ?? microAction
        }
    }
}

private struct FogLayer: View {
    @Environment(\.palette) private var palette
    var body: some View {
        ZStack {
            DriftingFogBlob(size: 320, color: palette.energyFoggy,   opacity: 0.32, phase: 0.0, durationSeconds: 22)
                .offset(x: -90, y: -120)
            DriftingFogBlob(size: 260, color: palette.bgRadialNW,    opacity: 0.28, phase: 0.4, durationSeconds: 26)
                .offset(x: 120, y: -40)
            DriftingFogBlob(size: 300, color: palette.energyFoggy,   opacity: 0.22, phase: 0.7, durationSeconds: 18)
                .offset(x: -40, y: 220)
        }
        .allowsHitTesting(false)
    }
}

private struct MicroActionCard: View {
    let text: String
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppStrings.restTryThisLabel)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(palette.parkedMeta)

            Text(text)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.parkedText)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                .fill(palette.parkedBg)
        )
        .shadow(color: palette.cardShadow, radius: 8, x: 0, y: 3)
    }
}
