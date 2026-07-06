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

    /// Message for the transient toast shown after toggling handedness from the editor's nav-bar
    /// button (`CustomKeyboardEditorViewController`). A pure, testable mapping — the toast's
    /// presentation/timing lives in the view.
    var toastMessage: String {
        switch self {
        case .left: return NSLocalizedString("Keyboard is now set to left-hand mode.", comment: "Toast shown after switching the custom keyboard to left-hand mode")
        case .right: return NSLocalizedString("Keyboard is now set to right-hand mode.", comment: "Toast shown after switching the custom keyboard to right-hand mode")
        }
    }
}
