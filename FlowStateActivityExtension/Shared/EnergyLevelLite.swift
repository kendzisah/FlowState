// Mirror of the subset of FlowState/Models/EnergyLevel.swift that the widget
// extension needs. The main-app EnergyLevel imports UIKit (haptic styles), so
// it can't compile here. Keep the rawValue cases + hexString + shortLabel +
// iconName aligned with the main app's enum.
import SwiftUI

enum EnergyLevelLite: String, Codable, CaseIterable, Hashable {
    case foggy
    case scattered
    case steady
    case locked

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

    var hexString: String {
        switch self {
        case .foggy:     return "8A857B"
        case .scattered: return "C48E75"
        case .steady:    return "C9A876"
        case .locked:    return "87A178"
        }
    }

    var color: Color { Color(hex: hexString) }
}

extension Color {
    /// Mirrors the hex initializer used in the Live Activity. Accepts 6-char
    /// or 8-char hex with optional leading `#`.
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
