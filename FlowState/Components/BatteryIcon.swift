import SwiftUI

struct BatteryIcon: View {
    let level: EnergyLevel
    var bodyColor: Color
    var fillColor: Color
    var width: CGFloat = 28
    var height: CGFloat = 14

    var body: some View {
        let cap = max(width * 0.07, 2)
        let bodyW = width - cap - 1
        let innerInset: CGFloat = 2
        let fillW = max((bodyW - innerInset * 2) * level.batteryFill, 0)

        ZStack(alignment: .leading) {
            HStack(spacing: 1) {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(bodyColor, lineWidth: 1.4)
                    .frame(width: bodyW, height: height)
                    .overlay(alignment: .leading) {
                        if fillW > 0 {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(fillColor)
                                .frame(width: fillW, height: height - innerInset * 2)
                                .padding(innerInset)
                        }
                    }
                RoundedRectangle(cornerRadius: 1)
                    .fill(bodyColor)
                    .frame(width: cap, height: height * 0.45)
            }
        }
        .frame(width: width, height: height)
    }
}

#Preview {
    VStack(spacing: 10) {
        BatteryIcon(level: .foggy,     bodyColor: .gray, fillColor: .gray)
        BatteryIcon(level: .scattered, bodyColor: .gray, fillColor: .orange)
        BatteryIcon(level: .steady,    bodyColor: .gray, fillColor: .yellow)
        BatteryIcon(level: .locked,    bodyColor: .gray, fillColor: .green)
    }
    .padding()
}
