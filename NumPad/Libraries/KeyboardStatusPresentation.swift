//
//  KeyboardStatusPresentation.swift
//  NumPad
//

import Foundation
import CoreGraphics

enum KeyboardStatusPresentation {
    static func detail(isEnabled: Bool) -> String? {
        isEnabled ? NSLocalizedString("On", comment: "Enabled setting status") : nil
    }
}

enum HomeDemoLayout {
    static func contentInset(fieldHeight: CGFloat, verticalMargin: CGFloat) -> CGFloat {
        fieldHeight + 2 * verticalMargin
    }
}
