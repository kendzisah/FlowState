import SwiftUI
import UIKit

enum EnergyLevel: String, Codable, CaseIterable, Hashable {
    case foggy
    case scattered
    case steady
    case locked

    var label: String {
        switch self {
        case .foggy:     return "Foggy — brain offline"
        case .scattered: return "Scattered — low focus"
        case .steady:    return "Steady — some focus"
        case .locked:    return "Locked in — high focus"
        }
    }

    var shortLabel: String {
        switch self {
        case .foggy:     return "Foggy"
        case .scattered: return "Scattered"
        case .steady:    return "Steady"
        case .locked:    return "Locked in"
        }
    }

    var iconName: String {
        switch self {
        case .foggy:     return "cloud.fill"
        case .scattered: return "leaf.fill"
        case .steady:    return "flame.fill"
        case .locked:    return "bolt.fill"
        }
    }

    var batteryFill: Double {
        switch self {
        case .foggy:     return 0.0
        case .scattered: return 0.33
        case .steady:    return 0.66
        case .locked:    return 1.0
        }
    }

    var defaultDurationSeconds: Int? {
        switch self {
        case .foggy:     return 5  * 60
        case .scattered: return 10 * 60
        case .steady:    return 25 * 60
        case .locked:    return nil
        }
    }

    nonisolated static let taskAssignable: [EnergyLevel] = [.scattered, .steady, .locked]

    var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .foggy, .scattered: return .light
        case .steady:            return .medium
        case .locked:            return .heavy
        }
    }

    var hapticIntensity: CGFloat {
        switch self {
        case .foggy:     return 0.4
        case .scattered: return 0.6
        case .steady:    return 0.8
        case .locked:    return 1.0
        }
    }

    func color(in palette: Palette) -> Color {
        switch self {
        case .foggy:     return palette.energyFoggy
        case .scattered: return palette.energyScattered
        case .steady:    return palette.energySteady
        case .locked:    return palette.energyLocked
        }
    }

    var hexString: String {
        switch self {
        case .foggy:     return "8A857B"
        case .scattered: return "C48E75"
        case .steady:    return "C9A876"
        case .locked:    return "87A178"
        }
    }
}

let durationPresetsSeconds: [Int?] = [
    5  * 60,
    10 * 60,
    15 * 60,
    25 * 60,
    45 * 60,
    60 * 60,
    nil
]
