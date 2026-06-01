import Foundation

/// Typed representation of every `flowstate://` URL the app accepts.
/// Parsing rejects unknown routes (returns nil) so a malformed URL never
/// triggers a partial action.
enum DeepLinkRoute: Equatable {
    case timer                          // flowstate://timer
    case checkin                        // flowstate://checkin
    case checkinWithLevel(String)       // flowstate://checkin/steady
    case task(UUID)                     // flowstate://task/<uuid>
    case parked                         // flowstate://parked
    case parkedLearn                    // flowstate://parked/learn
    case addTask                        // flowstate://add
    case routine(UUID)                  // flowstate://routine/<uuid>  (notification taps)

    static let scheme = "flowstate"

    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        // URL host is the first segment after `flowstate://`. URL.pathComponents
        // strips the leading "/" inconsistently; using the host + pathComponents
        // gives a stable shape.
        let host = url.host?.lowercased() ?? ""
        let rest = url.pathComponents.filter { $0 != "/" }

        switch (host, rest) {
        case ("timer", []):       self = .timer
        case ("checkin", []):     self = .checkin
        case ("checkin", let p) where p.count == 1:
            self = .checkinWithLevel(p[0].lowercased())
        case ("task", let p) where p.count == 1:
            guard let id = UUID(uuidString: p[0]) else { return nil }
            self = .task(id)
        case ("parked", []):      self = .parked
        case ("parked", ["learn"]): self = .parkedLearn
        case ("add", []):         self = .addTask
        case ("routine", let p) where p.count == 1:
            guard let id = UUID(uuidString: p[0]) else { return nil }
            self = .routine(id)
        default:                  return nil
        }
    }
}
