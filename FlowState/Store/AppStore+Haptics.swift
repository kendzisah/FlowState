import UIKit

extension AppStore {
    func fireEnergyHaptic(_ level: EnergyLevel) {
        let gen = UIImpactFeedbackGenerator(style: level.hapticStyle)
        gen.prepare()
        gen.impactOccurred(intensity: level.hapticIntensity)
    }

    func impactHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
    }

    func successHaptic() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }
}
