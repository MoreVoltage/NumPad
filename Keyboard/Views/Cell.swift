//
//  Cell.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/20/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import Foundation
import UIKit
import SwiftyTimer

class Cell: Button {
    var buttonTouchDown: ((UIButton) -> Void)?
    var buttonTapped: ((UIButton) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Hover highlight for iPad trackpad/mouse users; inert on touch-only devices.
        isPointerInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isPointerInteractionEnabled = true
    }

    /// Key label rendered by a plain UILabel instead of the button's titleLabel.
    ///
    /// When the iOS accessibility setting "Button Shapes" is on, UIKit underlines every
    /// UIButton plain title, which made keys unreadable (top public-review complaint).
    /// A UILabel is never decorated by Button Shapes, so we keep the button title nil
    /// and draw text ourselves. Touch handling, highlight states, and haptics are
    /// unaffected because they live on the button/cell itself, not the title label.
    private lazy var keyLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        return label
    }()

    @IBAction func _buttonTouchDown(sender: UIButton) {
        buttonTouchDown?(sender)
    }

    @IBAction func _buttonTapped(sender: UIButton) {
        buttonTapped?(sender)
    }

    // https://spin.atomicobject.com/2017/02/07/uistackviev-proportional-custom-uiviews/
    var width: CGFloat = UIView.noIntrinsicMetric
    override var intrinsicContentSize: CGSize {
        return CGSize(width: width, height: super.intrinsicContentSize.height)
    }

    /// Spoken VoiceOver label for a key. Image keys carry no title; some symbol titles read poorly
    /// letter-by-letter. Both map to localized phrases; everything else uses the visible title.
    static func accessibilityLabel(for item: Item) -> String? {
        switch item.imageName {
        case "next": return NSLocalizedString("Next keyboard", comment: "VoiceOver label for the next-keyboard key")
        case "back": return NSLocalizedString("Delete", comment: "VoiceOver label for the delete key")
        case "math", "math2": return NSLocalizedString("More symbols", comment: "VoiceOver label for the math/symbols toggle key")
        default: break
        }
        switch item.title {
        case "0x": return NSLocalizedString("Hexadecimal prefix", comment: "VoiceOver label for the 0x key")
        case "<<": return NSLocalizedString("Bit shift left", comment: "VoiceOver label for the << key")
        case ">>": return NSLocalizedString("Bit shift right", comment: "VoiceOver label for the >> key")
        case "+/-": return NSLocalizedString("Plus or minus", comment: "VoiceOver label for the sign-toggle key")
        default: return item.title
        }
    }
}

extension Cell {
    func configure(_ item: Item, roundedCorners: Bool, touchDown: @escaping () -> Void, tapped: @escaping () -> Void) {
        // Never set a plain button title — Button Shapes would underline it. Render via keyLabel.
        self.title = nil
        keyLabel.text = item.title
        keyLabel.isHidden = (item.title == nil)
        keyLabel.font = item.font
        // Let key labels scale with Dynamic Type and shrink rather than clip at large sizes.
        keyLabel.adjustsFontForContentSizeCategory = true
        keyLabel.adjustsFontSizeToFitWidth = true
        keyLabel.minimumScaleFactor = 0.5
        // Keep VoiceOver announcing the key even though the button has no title. Image keys have a
        // nil title, and a few symbol keys read poorly character-by-character, so map them to the
        // spoken labels shipped in Localizable.strings (all 17 locales).
        self.accessibilityLabel = Cell.accessibilityLabel(for: item)
        // Fall back to SF Symbols for keys without a bundled asset (e.g. the "globe" switch key).
        self.image = item.imageName.flatMap { UIImage(named: $0) ?? UIImage(systemName: $0) }.map { item.isReversed ? $0.imageFlippedForRightToLeftLayoutDirection() : $0 }
        self.setImage(self.image, for: .highlighted)
        self.setImage(self.image, for: .selected)
        self.scheme = item.style.scheme
        keyLabel.textColor = item.style.scheme.control
        self.layer.cornerRadius = roundedCorners ? 4 : 0
        self.layer.shadowOpacity = roundedCorners ? 1 : 0
        self.layer.shadowColor = item.style.scheme.highlightedBackground.withAlphaComponent(0.5).cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 1)
        self.layer.shadowRadius = 0
        self.removeTarget(nil, action: nil, for: .allEvents)
        self.addTarget(self, action: #selector(_buttonTouchDown), for: .touchDown)
        self.addTarget(self, action: #selector(_buttonTapped), for: .touchUpInside)
        buttonTouchDown = { _ in touchDown() }
        buttonTapped = { _ in tapped() }
    }
}
