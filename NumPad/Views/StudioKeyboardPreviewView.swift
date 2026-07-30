//
//  StudioKeyboardPreviewView.swift
//  NumPad
//

import UIKit

/// A truthful, non-interactive rendering of what the keyboard will actually look like.
final class StudioKeyboardPreviewView: UIView {
    private let borderView = UIView()
    private let leadingCaption = UILabel()
    private let trailingCaption = UILabel()
    private let palette: StudioPalette
    private var renderedLabels: [UILabel] = []

    /// Kept internal for UI-level regression tests; these are presentation views, never controls.
    private(set) var renderedKeyViews: [UIView] = []
    private(set) var glassBlurView = UIVisualEffectView(effect: nil)

    var model: StudioKeyboardPreviewModel {
        didSet {
            guard model != oldValue else { return }
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var isCompact = false {
        didSet {
            guard isCompact != oldValue else { return }
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    init(model: StudioKeyboardPreviewModel, palette: StudioPalette = .standard) {
        self.model = model
        self.palette = palette
        super.init(frame: .zero)
        commonInit()
    }

    required init?(coder: NSCoder) {
        self.model = .current(idiom: UIDevice.current.userInterfaceIdiom)
        self.palette = .standard
        super.init(coder: coder)
        commonInit()
    }

    override var intrinsicContentSize: CGSize {
        let referenceWidth: CGFloat = isCompact ? 220 : 320
        return CGSize(width: UIView.noIntrinsicMetric, height: referenceWidth * model.aspectRatio)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        render()
    }

    /// Optional caption strip, e.g. "LIVE PREVIEW" / "Regular · Calculations".
    func setCaption(leading: String?, trailing: String?) {
        leadingCaption.text = leading
        leadingCaption.isHidden = leading == nil
        trailingCaption.text = trailing
        trailingCaption.isHidden = trailing == nil
        setNeedsLayout()
    }

    private func commonInit() {
        isAccessibilityElement = true
        accessibilityTraits = .image
        accessibilityHint = NSLocalizedString("Visual preview of the selected keyboard.", comment: "Keyboard preview accessibility hint")
        accessibilityElementsHidden = true
        layer.cornerRadius = 16
        layer.masksToBounds = true

        glassBlurView.isUserInteractionEnabled = false
        addSubview(glassBlurView)
        borderView.isUserInteractionEnabled = false
        borderView.layer.borderWidth = 1 / displayScale
        borderView.layer.borderColor = palette.divider.cgColor
        addSubview(borderView)

        [leadingCaption, trailingCaption].forEach {
            $0.font = .preferredFont(forTextStyle: .caption1)
            $0.adjustsFontForContentSizeCategory = true
            $0.textColor = palette.textSecondary
            $0.isAccessibilityElement = false
            addSubview($0)
        }
        leadingCaption.textAlignment = .left
        trailingCaption.textAlignment = .right
    }

    private func render() {
        renderedKeyViews.forEach { $0.removeFromSuperview() }
        renderedKeyViews.removeAll()
        renderedLabels.removeAll()

        borderView.frame = bounds
        borderView.layer.cornerRadius = layer.cornerRadius
        glassBlurView.frame = bounds
        applyTheme()
        updateAccessibility()

        let captionHeight = captionStripHeight
        leadingCaption.frame = CGRect(x: 12, y: 8, width: bounds.width * 0.5 - 12, height: captionHeight)
        trailingCaption.frame = CGRect(x: bounds.width * 0.5, y: 8, width: bounds.width * 0.5 - 12, height: captionHeight)
        let availableContent = bounds
            .insetBy(dx: isCompact ? 6 : 10, dy: isCompact ? 6 : 10)
            .inset(by: UIEdgeInsets(top: captionHeight, left: 0, bottom: 0, right: 0))
        let maximumPreviewHeight = KeyboardHeightPreset.kiosk.baseHeight(idiom: model.idiom)
        let heightFraction = model.heightPreset.baseHeight(idiom: model.idiom) / maximumPreviewHeight
        let keyboardHeight = availableContent.height * min(1, heightFraction)
        let content = CGRect(
            x: availableContent.minX,
            y: availableContent.maxY - keyboardHeight,
            width: availableContent.width,
            height: keyboardHeight
        )
        guard content.width > 0, content.height > 0, !model.captionRows.isEmpty else { return }

        let rowSpacing: CGFloat = model.hasGrid ? (isCompact ? 2 : 4) : 0
        let keyHeight = max(12, (content.height - rowSpacing * CGFloat(model.captionRows.count - 1)) / CGFloat(model.captionRows.count))
        for (rowIndex, captions) in model.captionRows.enumerated() where !captions.isEmpty {
            let y = content.minY + CGFloat(rowIndex) * (keyHeight + rowSpacing)
            let keySpacing: CGFloat = model.hasGrid ? (isCompact ? 2 : 4) : 0
            let keyWidth = max(8, (content.width - keySpacing * CGFloat(captions.count - 1)) / CGFloat(captions.count))
            for (columnIndex, caption) in captions.enumerated() {
                let key = makeKey(caption: caption)
                key.frame = CGRect(
                    x: content.minX + CGFloat(columnIndex) * (keyWidth + keySpacing),
                    y: y,
                    width: keyWidth,
                    height: keyHeight
                )
                addSubview(key)
                renderedKeyViews.append(key)
            }
        }
    }

    private var captionStripHeight: CGFloat {
        leadingCaption.isHidden && trailingCaption.isHidden ? 0 : (isCompact ? 18 : 24)
    }

    private var displayScale: CGFloat {
        traitCollection.displayScale > 0 ? traitCollection.displayScale : 2
    }

    private func makeKey(caption: KeyboardLayoutCaption) -> UIView {
        let key = UIView()
        key.isAccessibilityElement = false
        key.backgroundColor = keyColor(for: caption.style)
        key.layer.cornerRadius = model.hasRoundedCorners ? (isCompact ? 8 : 14) : 0
        key.layer.borderWidth = model.hasGrid ? 1 / displayScale : 0
        key.layer.borderColor = palette.divider.withAlphaComponent(0.7).cgColor

        switch caption.presentation {
        case .text:
            let label = UILabel()
            label.text = caption.previewText
            label.textAlignment = .center
            label.textColor = keyTextColor
            label.font = caption.usesTextFont
                ? .systemFont(ofSize: isCompact ? 8 : 12, weight: .medium)
                : .monospacedDigitSystemFont(ofSize: isCompact ? 10 : 15, weight: .medium)
            label.adjustsFontForContentSizeCategory = true
            label.minimumScaleFactor = 0.55
            label.adjustsFontSizeToFitWidth = true
            label.isAccessibilityElement = false
            key.addSubview(label)
            label.frame = key.bounds
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            renderedLabels.append(label)
        case .image:
            let imageView = UIImageView(image: previewImage(for: caption.value))
            imageView.contentMode = .scaleAspectFit
            imageView.tintColor = keyTextColor
            imageView.isAccessibilityElement = false
            key.addSubview(imageView)
            imageView.frame = key.bounds.insetBy(dx: isCompact ? 4 : 8, dy: isCompact ? 4 : 8)
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }
        return key
    }

    private func previewImage(for name: String) -> UIImage? {
        UIImage(named: name) ?? UIImage(systemName: {
            switch name {
            case KeyGlyph.packSwitch: return KeyGlyph.packSwitch
            case "back": return "delete.left"
            case "globe": return "globe"
            case "math", "math2": return "function"
            default: return name
            }
        }())
    }

    private func applyTheme() {
        if model.theme.isGlass {
            glassBlurView.effect = UIBlurEffect(style: model.theme == .glassDark ? .systemMaterialDark : .systemMaterialLight)
            glassBlurView.isHidden = false
            backgroundColor = .clear
        } else {
            glassBlurView.effect = nil
            glassBlurView.isHidden = true
            backgroundColor = model.theme == .black
                ? UIColor(white: 0.15, alpha: 1)
                : model.theme.color.previewIsLight ? model.theme.color.previewDarkened(by: 0.08) : model.theme.color.previewLightened(by: 0.12)
        }
    }

    private var keyColor: UIColor {
        model.theme == .black ? UIColor(white: 0.22, alpha: 1) : model.theme.color
    }

    private func keyColor(for style: KeyboardLayoutCaption.Style) -> UIColor {
        guard style != .default else { return keyColor }
        return model.theme == .black
            ? keyColor.previewLightened(by: 0.05)
            : (model.theme.color.previewIsLight
                ? keyColor.previewDarkened(by: 0.05)
                : keyColor.previewLightened(by: 0.05))
    }

    private var keyTextColor: UIColor {
        model.theme == .black || !model.theme.color.previewIsLight ? .white : .black
    }

    private func updateAccessibility() {
        accessibilityLabel = String(
            format: NSLocalizedString(
                "Keyboard preview: %@ key set, %@ theme, %@ height",
                comment: "VoiceOver summary for the keyboard preview"
            ),
            model.pack.name,
            model.theme.name,
            model.heightPreset.name
        )
    }
}

private extension UIColor {
    var previewIsLight: Bool {
        let rgba = previewRGBA
        return 0.299 * rgba.r + 0.587 * rgba.g + 0.114 * rgba.b > 0.6
    }

    func previewLightened(by amount: CGFloat) -> UIColor {
        let rgba = previewRGBA
        return UIColor(red: min(1, rgba.r + amount), green: min(1, rgba.g + amount), blue: min(1, rgba.b + amount), alpha: rgba.a)
    }

    func previewDarkened(by amount: CGFloat) -> UIColor {
        let rgba = previewRGBA
        return UIColor(red: max(0, rgba.r - amount), green: max(0, rgba.g - amount), blue: max(0, rgba.b - amount), alpha: rgba.a)
    }

    private var previewRGBA: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return (red, green, blue, alpha)
        }
        var white: CGFloat = 0
        if getWhite(&white, alpha: &alpha) {
            return (white, white, white, alpha)
        }
        return (0, 0, 0, 1)
    }
}
