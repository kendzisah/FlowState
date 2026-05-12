import SwiftUI

struct Step09TransitionReady: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            FoggyMascot(size: 120)

            Text("Ready to unlock your planning potential?")
                .font(.system(size: 28, weight: .bold))
                .tracking(AppFont.titleTracking)
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
        }
    }
}

struct Step14TransitionCapture: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            FoggyMascot(size: 120)

            Text("Routines sorted. Time to capture this week's plans.")
                .font(.system(size: 26, weight: .bold))
                .tracking(AppFont.titleTracking)
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
        }
    }
}
