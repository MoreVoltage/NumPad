//
//  StudioSectionLabel.swift
//  NumPad
//
//  Studio design system — uppercase section label.
//

import UIKit

/// Uppercase group heading. The caller supplies the localised text; the label
/// uppercases for display but reports the original string to VoiceOver so it is
/// not spelled out letter by letter.
final class StudioSectionLabel: UILabel {

    public var palette: StudioPalette {
        didSet { textColor = palette.textSecondary }
    }

    /// The text in its original (non-uppercased) form.
    public var sectionText: String {
        didSet { applyText() }
    }

    public init(text: String, palette: StudioPalette = .standard) {
        self.sectionText = text
        self.palette = palette
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        StudioTypography.apply(.sectionLabel, to: self, color: palette.textSecondary)
        accessibilityTraits = .header
        applyText()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("StudioSectionLabel is programmatic only")
    }

    private func applyText() {
        StudioTypography.applyTracked(.sectionLabel, text: sectionText.localizedUppercase, to: self)
        accessibilityLabel = sectionText
    }

    @objc private func contentSizeCategoryDidChange() {
        applyText()
    }
}
