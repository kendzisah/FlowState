import ActivityKit
import AppIntents
import WidgetKit
import SwiftUI

/// FlowState's Live Activity. Renders four phases:
///   • `.active` — running countdown / count-up
///   • `.lastMinute` — countdown ≤60s, text turns red, gently pulses
///   • `.complete` — session-complete banner (10s linger before auto-end)
///   • `.parked` — task-parked banner with parked-queue depth (10s linger)
///
/// Compact / Minimal renderings only differentiate active vs lastMinute; the
/// complete/parked banners use a checkmark or pause glyph in the trailing slot
/// to give a glance-clear "what just happened" signal.
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
                    trailingTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    centerHeadline(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedActions(context: context)
                }
            } compactLeading: {
                compactLeading(context: context)
            } compactTrailing: {
                compactTrailing(context: context)
            } minimal: {
                minimal(context: context)
            }
        }
    }

    // MARK: - Compact / Minimal

    @ViewBuilder
    private func compactLeading(context: ActivityViewContext<FlowStateActivityAttributes>) -> some View {
        switch context.state.phase {
        case .active, .lastMinute:
            Circle()
                .fill(Color(hex: context.attributes.energyHex))
                .frame(width: 10, height: 10)
        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(hex: context.attributes.energyHex))
        case .parked:
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(Color(hex: context.attributes.energyHex))
        }
    }

    @ViewBuilder
    private func compactTrailing(context: ActivityViewContext<FlowStateActivityAttributes>) -> some View {
        switch context.state.phase {
        case .active, .lastMinute:
            timerText(context: context)
                .font(.caption.monospacedDigit())
                .foregroundStyle(textTint(for: context.state.phase))
                .pulseIfLastMinute(context.state.phase == .lastMinute)
        case .complete:
            Text("Done")
                .font(.caption.weight(.semibold))
        case .parked:
            Text("Parked")
                .font(.caption.weight(.semibold))
        }
    }

    @ViewBuilder
    private func minimal(context: ActivityViewContext<FlowStateActivityAttributes>) -> some View {
        switch context.state.phase {
        case .active, .lastMinute:
            Circle()
                .fill(textTint(for: context.state.phase))
                .frame(width: 10, height: 10)
                .pulseIfLastMinute(context.state.phase == .lastMinute)
        case .complete:
            Image(systemName: "checkmark")
                .foregroundStyle(Color(hex: context.attributes.energyHex))
        case .parked:
            Image(systemName: "pause.fill")
                .foregroundStyle(Color(hex: context.attributes.energyHex))
        }
    }

    // MARK: - Expanded

    @ViewBuilder
    private func centerHeadline(context: ActivityViewContext<FlowStateActivityAttributes>) -> some View {
        switch context.state.phase {
        case .active, .lastMinute:
            Text(context.attributes.taskTitle)
                .font(.callout.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        case .complete:
            VStack(spacing: 2) {
                Text("Session complete")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(context.attributes.taskTitle)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
            }
        case .parked:
            VStack(spacing: 2) {
                Text("Parked at \(elapsedLabel(context.state.secondsElapsed))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(context.attributes.taskTitle)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func trailingTrailing(context: ActivityViewContext<FlowStateActivityAttributes>) -> some View {
        switch context.state.phase {
        case .active, .lastMinute:
            timerText(context: context)
                .font(.system(size: 22, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(textTint(for: context.state.phase))
                .pulseIfLastMinute(context.state.phase == .lastMinute)
        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(Color(hex: context.attributes.energyHex))
        case .parked:
            Image(systemName: "pause.circle.fill")
                .font(.title2)
                .foregroundStyle(Color(hex: context.attributes.energyHex))
        }
    }

    @ViewBuilder
    private func expandedActions(context: ActivityViewContext<FlowStateActivityAttributes>) -> some View {
        switch context.state.phase {
        case .active, .lastMinute:
            HStack(spacing: 8) {
                Button(intent: ParkTaskIntent(taskID: context.attributes.taskID)) {
                    Label("Park This", systemImage: "pause.fill")
                        .font(.caption.weight(.semibold))
                }
                .tint(Color(hex: "C9A876"))
                Button(intent: StopTaskIntent(taskID: context.attributes.taskID)) {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.caption.weight(.semibold))
                }
                .tint(.secondary)
            }
        case .complete:
            // No buttons — banner auto-dismisses after the linger window.
            EmptyView()
        case .parked:
            EmptyView()
        }
    }

    // MARK: - Helpers

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

    private func textTint(for phase: FlowStateActivityAttributes.Phase) -> Color {
        switch phase {
        case .lastMinute: return Color(hex: "E25E5E") // warm red, not alarming
        default:          return Color(hex: "EFEAE2")
        }
    }

    private func elapsedLabel(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Lock-screen banner

private struct LockScreenBanner: View {
    let context: ActivityViewContext<FlowStateActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            phaseIcon
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.taskTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "EFEAE2"))
                    .lineLimit(2)
                Text(secondaryLabel)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Color(hex: "A89F94"))
            }

            Spacer(minLength: 8)

            switch context.state.phase {
            case .active, .lastMinute:
                timerLabel
            case .complete, .parked:
                actionRow
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var phaseIcon: some View {
        switch context.state.phase {
        case .active, .lastMinute:
            Circle()
                .fill(Color(hex: context.attributes.energyHex))
                .frame(width: 12, height: 12)
        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(hex: context.attributes.energyHex))
                .font(.title3)
        case .parked:
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(Color(hex: context.attributes.energyHex))
                .font(.title3)
        }
    }

    private var secondaryLabel: String {
        switch context.state.phase {
        case .active, .lastMinute: return "FOCUS SESSION"
        case .complete:            return "SESSION COMPLETE"
        case .parked:              return "PARKED"
        }
    }

    @ViewBuilder
    private var timerLabel: some View {
        Group {
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
        .font(.system(size: 28, weight: .light, design: .monospaced))
        .monospacedDigit()
        .foregroundStyle(textColor(for: context.state.phase))
        .pulseIfLastMinute(context.state.phase == .lastMinute)
    }

    @ViewBuilder
    private var actionRow: some View {
        // Lock-screen Live Activity banners can render buttons that trigger
        // AppIntents. They appear as tappable affordances on the lock screen.
        switch context.state.phase {
        case .parked:
            Button(intent: ResumeTaskIntent(parkedID: context.attributes.taskID)) {
                Text("Resume")
                    .font(.system(size: 13, weight: .semibold))
            }
            .tint(Color(hex: context.attributes.energyHex))
        default:
            EmptyView()
        }
    }

    private func textColor(for phase: FlowStateActivityAttributes.Phase) -> Color {
        phase == .lastMinute ? Color(hex: "E25E5E") : Color(hex: "EFEAE2")
    }
}

// MARK: - Pulse modifier

private struct LastMinutePulse: ViewModifier {
    let active: Bool
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(active && pulsing ? 0.55 : 1.0)
            .animation(
                active
                    ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                    : .default,
                value: pulsing
            )
            .onAppear { if active { pulsing.toggle() } }
            .onChange(of: active) { _, new in pulsing = new }
    }
}

private extension View {
    /// Gentle pulse for the final 60s of a countdown. Subtle, not alarming —
    /// the brand voice rewards completion, doesn't pressure for it.
    func pulseIfLastMinute(_ active: Bool) -> some View {
        modifier(LastMinutePulse(active: active))
    }
}

// `Color.init(hex: String)` is defined in EnergyLevelLite.swift (shared
// utility in this target).
