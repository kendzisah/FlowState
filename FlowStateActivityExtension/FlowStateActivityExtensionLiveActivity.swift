import ActivityKit
import WidgetKit
import SwiftUI

struct FlowStateLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlowStateActivityAttributes.self) { context in
            LockScreenBanner(context: context)
                .activityBackgroundTint(Color(hex: "26221E"))
                .activitySystemActionForegroundColor(Color(hex: "EFEAE2"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: context.attributes.energyHex))
                            .frame(width: 8, height: 8)
                        Text("FlowState")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerText(context: context)
                        .font(.system(size: 22, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.taskTitle)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    EmptyView()
                }
            } compactLeading: {
                Circle()
                    .fill(Color(hex: context.attributes.energyHex))
                    .frame(width: 10, height: 10)
            } compactTrailing: {
                timerText(context: context)
                    .font(.caption.monospacedDigit())
            } minimal: {
                Circle()
                    .fill(Color(hex: context.attributes.energyHex))
                    .frame(width: 10, height: 10)
            }
        }
    }

    @ViewBuilder
    private func timerText(context: ActivityViewContext<FlowStateActivityAttributes>) -> some View {
        switch context.attributes.mode {
        case .countdown:
            if let endDate = context.state.endDate {
                Text(timerInterval: Date()...endDate, countsDown: true)
            } else {
                Text("--:--")
            }
        case .countup:
            Text(timerInterval: context.state.startDate...Date.distantFuture, countsDown: false)
        }
    }
}

private struct LockScreenBanner: View {
    let context: ActivityViewContext<FlowStateActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(hex: context.attributes.energyHex))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.taskTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "EFEAE2"))
                    .lineLimit(2)
                Text("FOCUS SESSION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Color(hex: "A89F94"))
            }

            Spacer(minLength: 8)

            switch context.attributes.mode {
            case .countdown:
                if let endDate = context.state.endDate {
                    Text(timerInterval: Date()...endDate, countsDown: true)
                        .font(.system(size: 28, weight: .light, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(Color(hex: "EFEAE2"))
                } else {
                    Text("--:--")
                        .font(.system(size: 28, weight: .light, design: .monospaced))
                        .foregroundStyle(Color(hex: "EFEAE2"))
                }
            case .countup:
                Text(timerInterval: context.state.startDate...Date.distantFuture, countsDown: false)
                    .font(.system(size: 28, weight: .light, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: "EFEAE2"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8)  & 0xFF) / 255.0
        let b = Double(v         & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
