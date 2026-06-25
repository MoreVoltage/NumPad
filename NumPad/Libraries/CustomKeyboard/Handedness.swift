import Foundation

/// Which side the customizable peripheral columns sit on, relative to the fixed numpad.
/// Right-handed (the default) places both columns to the right of the numpad; left-handed mirrors
/// them to the left. Independent of the existing reversed (7-8-9-on-top) mode.
enum Handedness: String, Codable, CaseIterable {
    case left, right

    static let `default`: Handedness = .right

    var name: String {
        switch self {
        case .left: return NSLocalizedString("Left-handed", comment: "Handedness option: columns on the left")
        case .right: return NSLocalizedString("Right-handed", comment: "Handedness option: columns on the right")
        }
    }
}
