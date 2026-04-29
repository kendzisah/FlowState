import SwiftUI

enum ThemeMode: String, CaseIterable, Codable {
    case system, dark, light

    var preferred: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

struct Palette: Equatable {
    let surface: Color
    let surfaceAlt: Color
    let border: Color

    let textPrimary: Color
    let textSecondary: Color
    let textDimmed: Color

    let onEnergy: Color
    let energyFoggy: Color
    let energyScattered: Color
    let energySteady: Color
    let energyLocked: Color

    let parkedBg: Color
    let parkedText: Color
    let parkedMeta: Color
    let parkedAccent: Color

    let sheetBackdrop: Color
    let cardShadow: Color
    let captionPulse: Color

    let bgGradientStart: Color
    let bgGradientEnd: Color
    let bgRadialNW: Color
    let bgRadialSE: Color
}

extension Palette {
    static let dark = Palette(
        surface:          Color(hex: 0x26221E),
        surfaceAlt:       Color(hex: 0x35302B),
        border:           Color(hex: 0x35302B),
        textPrimary:      Color(hex: 0xEFEAE2),
        textSecondary:    Color(hex: 0xA89F94),
        textDimmed:       Color(hex: 0x6B655D),
        onEnergy:         Color(hex: 0x1E1A16),
        energyFoggy:      Color(hex: 0x8A857B),
        energyScattered:  Color(hex: 0xC48E75),
        energySteady:     Color(hex: 0xC9A876),
        energyLocked:     Color(hex: 0x87A178),
        parkedBg:         Color(hex: 0xECDDC8),
        parkedText:       Color(hex: 0x2B2520),
        parkedMeta:       Color(hex: 0x7A6F62),
        parkedAccent:     Color(hex: 0xC9A876),
        sheetBackdrop:    Color(hex: 0x0E0B08, opacity: 0.6),
        cardShadow:       Color.black.opacity(0.22),
        captionPulse:     Color(hex: 0x5F7D5F),
        bgGradientStart:  Color(hex: 0x2A2420),
        bgGradientEnd:    Color(hex: 0x13110E),
        bgRadialNW:       Color(hex: 0x4A3E30),
        bgRadialSE:       Color(hex: 0x2B2A1F)
    )

    static let light = Palette(
        surface:          Color(hex: 0xEAE0D0),
        surfaceAlt:       Color(hex: 0xDCCFBB),
        border:           Color(hex: 0xD0C2AD),
        textPrimary:      Color(hex: 0x2B2520),
        textSecondary:    Color(hex: 0x7A6F62),
        textDimmed:       Color(hex: 0xA89E90),
        onEnergy:         Color(hex: 0xF2ECE0),
        energyFoggy:      Color(hex: 0x6B665C),
        energyScattered:  Color(hex: 0xA65F48),
        energySteady:     Color(hex: 0x8B6E35),
        energyLocked:     Color(hex: 0x5D7B4E),
        parkedBg:         Color(hex: 0xECDDC8),
        parkedText:       Color(hex: 0x2B2520),
        parkedMeta:       Color(hex: 0x7A6F62),
        parkedAccent:     Color(hex: 0x8B6E35),
        sheetBackdrop:    Color(hex: 0x2B2520, opacity: 0.35),
        cardShadow:       Color(hex: 0x2B2520, opacity: 0.08),
        captionPulse:     Color(hex: 0x5F7D5F),
        bgGradientStart:  Color(hex: 0xF2ECE0),
        bgGradientEnd:    Color(hex: 0xDFCCB3),
        bgRadialNW:       Color(hex: 0xF8F2E8),
        bgRadialSE:       Color(hex: 0xD4C4A8)
    )

    static func resolve(_ mode: ThemeMode, system: ColorScheme) -> Palette {
        switch mode {
        case .system: return system == .dark ? .dark : .light
        case .dark:   return .dark
        case .light:  return .light
        }
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: Palette = .dark
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8)  & 0xFF) / 255.0
        let b = Double(hex         & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

enum AppFont {
    static let title = Font.system(size: 34, weight: .bold)
    static let body = Font.system(size: 16, weight: .medium)
    static let caption = Font.system(size: 13, weight: .semibold)
    static let timerNumerals = Font.system(size: 50, weight: .light, design: .monospaced)

    static let titleTracking: CGFloat = -0.68
    static let timerTracking: CGFloat = -1.0
}
