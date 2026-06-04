//
//  KeyboardPreviewView.swift
//  NumPad
//
//  A lightweight, non-interactive visual representation of the keyboard used
//  to live-preview the selected theme inside the container app settings.
//

import UIKit

final class KeyboardPreviewView: UIView {
    private let borderView = UIView()
    private var keyLayers: [CAShapeLayer] = []
    private var keyLabels: [CATextLayer] = []

    /// Theme rendered by the preview. Setting it redraws immediately.
    var theme: KeyboardTheme = .selectedOrAutomatic {
        didSet {
            guard theme != oldValue else { return }
            setNeedsLayout()
            layoutIfNeeded()
        }
    }

    // Grid config (approximate visual of the NumPad layout: 4 rows, 3 number
    // columns + a narrower action column on the right)
    private let rows = 4
    private let cols = 4
    private let keyCornerRadius: CGFloat = 6
    private let keySpacing: CGFloat = 4
    private let contentInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    private let keyTitles: [[String]] = [
        ["1", "2", "3", "⌫"],
        ["4", "5", "6", "−"],
        ["7", "8", "9", "+"],
        [".", "0", "%", "⏎"]
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = UIColor.secondarySystemBackground
        layer.masksToBounds = true
        layer.cornerRadius = 12

        borderView.isUserInteractionEnabled = false
        borderView.layer.borderColor = UIColor.separator.cgColor
        borderView.layer.borderWidth = 1 / hairlineScale
        borderView.layer.cornerRadius = 12
        addSubview(borderView)
        borderView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            borderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            borderView.trailingAnchor.constraint(equalTo: trailingAnchor),
            borderView.topAnchor.constraint(equalTo: topAnchor),
            borderView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    /// Display scale for hairline borders. `traitCollection.displayScale` replaces the
    /// deprecated `UIScreen.main.scale` and is multi-display / Stage Manager safe.
    private var hairlineScale: CGFloat {
        let scale = traitCollection.displayScale
        return scale > 0 ? scale : 2
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawKeys()
    }

    private func drawKeys() {
        // Clear existing
        keyLayers.forEach { $0.removeFromSuperlayer() }
        keyLayers.removeAll()
        keyLabels.forEach { $0.removeFromSuperlayer() }
        keyLabels.removeAll()

        let contentRect = bounds.inset(by: contentInset)
        guard contentRect.width > 0, contentRect.height > 0 else { return }

        // Surrounding panel tinted like the keyboard border so the preview reads as a keyboard.
        let isLight = isLightColor(theme.color)
        backgroundColor = theme == .black
            ? UIColor(white: 0.15, alpha: 1)
            : (isLight ? theme.color.darkenedForPreview(0.08) : theme.color.lightenedForPreview(0.12))

        let totalHSpacing = keySpacing * CGFloat(cols - 1)
        let totalVSpacing = keySpacing * CGFloat(rows - 1)
        let keyWidth = max(6, (contentRect.width - totalHSpacing) / CGFloat(cols))
        let keyHeight = max(10, (contentRect.height - totalVSpacing) / CGFloat(rows))

        let keyFill = theme == .black ? UIColor(white: 0.22, alpha: 1) : theme.color
        let textColor: UIColor = theme == .black ? .white : (isLight ? .black : .white)

        for r in 0..<rows {
            for c in 0..<cols {
                let x = contentRect.minX + CGFloat(c) * (keyWidth + keySpacing)
                let y = contentRect.minY + CGFloat(r) * (keyHeight + keySpacing)
                let rect = CGRect(x: x, y: y, width: keyWidth, height: keyHeight)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: keyCornerRadius)
                let shape = CAShapeLayer()
                shape.path = path.cgPath
                shape.fillColor = keyFill.cgColor
                shape.strokeColor = UIColor.separator.cgColor
                shape.lineWidth = 1 / hairlineScale
                layer.addSublayer(shape)
                keyLayers.append(shape)

                // Key caption
                let text = CATextLayer()
                text.string = keyTitles[r][c]
                text.alignmentMode = .center
                text.contentsScale = hairlineScale
                let fontSize = min(20, keyHeight * 0.45)
                text.fontSize = fontSize
                text.font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
                text.foregroundColor = textColor.cgColor
                text.frame = CGRect(x: rect.minX, y: rect.midY - fontSize * 0.62, width: rect.width, height: fontSize * 1.4)
                layer.addSublayer(text)
                keyLabels.append(text)
            }
        }
    }

    /// Perceived-luminance check; mirrors the keyboard's light/dark text heuristic
    /// without depending on DynamicColor (app target keeps the preview self-contained).
    private func isLightColor(_ color: UIColor) -> Bool {
        let rgba = color.previewRGBA
        let luminance = 0.299 * rgba.r + 0.587 * rgba.g + 0.114 * rgba.b
        return luminance > 0.6
    }
}

private extension UIColor {
    /// RGBA components that also work for grayscale colors like `.white` / `.black`
    /// (plain `getRed` fails for non-RGB colorspaces).
    var previewRGBA: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (r, g, b, a)
        }
        var white: CGFloat = 0, alpha: CGFloat = 0
        if getWhite(&white, alpha: &alpha) {
            return (white, white, white, alpha)
        }
        return (0, 0, 0, 1)
    }
    func lightenedForPreview(_ amount: CGFloat) -> UIColor {
        let c = previewRGBA
        return UIColor(red: min(1, c.r + amount), green: min(1, c.g + amount), blue: min(1, c.b + amount), alpha: c.a)
    }
    func darkenedForPreview(_ amount: CGFloat) -> UIColor {
        let c = previewRGBA
        return UIColor(red: max(0, c.r - amount), green: max(0, c.g - amount), blue: max(0, c.b - amount), alpha: c.a)
    }
}
