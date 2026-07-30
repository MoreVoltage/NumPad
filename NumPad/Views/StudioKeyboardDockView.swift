//
//  StudioKeyboardDockView.swift
//  NumPad
//

import UIKit

/// A permanent, non-scrolling home for the live keyboard preview in the iPad Studio workspace.
/// Its parent owns placement and bottom pinning; this view only owns the truthful visual content.
final class StudioKeyboardDockView: UIView {
    let preview: StudioKeyboardPreviewView

    init(
        model: StudioKeyboardPreviewModel = .current(idiom: .pad),
        palette: StudioPalette = .standard
    ) {
        preview = StudioKeyboardPreviewView(model: model, palette: palette)
        super.init(frame: .zero)
        commonInit()
    }

    required init?(coder: NSCoder) {
        preview = StudioKeyboardPreviewView(model: .current(idiom: .pad), palette: .standard)
        super.init(coder: coder)
        commonInit()
    }

    func refresh(model: StudioKeyboardPreviewModel) {
        preview.model = model
        accessibilityLabel = preview.accessibilityLabel
    }

    private func commonInit() {
        accessibilityIdentifier = "studio.keyboard-dock"
        accessibilityLabel = NSLocalizedString("Live keyboard preview", comment: "iPad Studio dock accessibility label")
        isAccessibilityElement = true
        backgroundColor = StudioTheme.standard.surfaceElevated
        layer.borderWidth = 1 / max(traitCollection.displayScale, 1)
        layer.borderColor = StudioTheme.standard.divider.cgColor

        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.accessibilityIdentifier = "studio.keyboard-dock.preview"
        preview.setCaption(
            leading: NSLocalizedString("LIVE KEYBOARD", comment: "iPad Studio dock caption"),
            trailing: nil
        )
        addSubview(preview)
        NSLayoutConstraint.activate([
            preview.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            preview.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            preview.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            preview.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }
}
