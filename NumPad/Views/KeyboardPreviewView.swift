//
//  KeyboardPreviewView.swift
//  NumPad
//
//  Compatibility façade for legacy callers. New code should use
//  StudioKeyboardPreviewView with an explicit StudioKeyboardPreviewModel.
//

import UIKit

final class KeyboardPreviewView: UIView {
    private let preview: StudioKeyboardPreviewView

    /// Retained for callers that historically previewed a theme only. The rest of the preview
    /// stays live and truthful through `StudioKeyboardPreviewModel.current(idiom:)`.
    var theme: KeyboardTheme = .selectedOrAutomatic {
        didSet {
            guard theme != oldValue else { return }
            preview.model.theme = theme
        }
    }

    override init(frame: CGRect) {
        preview = StudioKeyboardPreviewView(model: .current(idiom: UIDevice.current.userInterfaceIdiom))
        super.init(frame: frame)
        installPreview()
    }

    required init?(coder: NSCoder) {
        preview = StudioKeyboardPreviewView(model: .current(idiom: UIDevice.current.userInterfaceIdiom))
        super.init(coder: coder)
        installPreview()
    }

    private func installPreview() {
        preview.translatesAutoresizingMaskIntoConstraints = false
        addSubview(preview)
        NSLayoutConstraint.activate([
            preview.leadingAnchor.constraint(equalTo: leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: trailingAnchor),
            preview.topAnchor.constraint(equalTo: topAnchor),
            preview.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
