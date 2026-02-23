//
//  KeyboardPreviewView.swift
//  NumPad
//
//  A lightweight, non-interactive visual representation of the keyboard used
//  to preview height changes inside the container app settings.
//

import UIKit

final class KeyboardPreviewView: UIView {
    private let borderView = UIView()
    private var keyLayers: [CAShapeLayer] = []

    // Grid config (approximate visual of a numpad)
    private let rows = 4
    private let cols = 10
    private let keyCornerRadius: CGFloat = 6
    private let keySpacing: CGFloat = 6
    private let contentInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

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
        borderView.layer.borderWidth = 1 / UIScreen.main.scale
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

    override func layoutSubviews() {
        super.layoutSubviews()
        drawKeys()
    }

    private func drawKeys() {
        // Clear existing
        keyLayers.forEach { $0.removeFromSuperlayer() }
        keyLayers.removeAll()

        let contentRect = bounds.inset(by: contentInset)
        guard contentRect.width > 0, contentRect.height > 0 else { return }

        let totalHSpacing = keySpacing * CGFloat(cols - 1)
        let totalVSpacing = keySpacing * CGFloat(rows - 1)
        let keyWidth = max(6, (contentRect.width - totalHSpacing) / CGFloat(cols))
        let keyHeight = max(10, (contentRect.height - totalVSpacing) / CGFloat(rows))

        for r in 0..<rows {
            for c in 0..<cols {
                let x = contentRect.minX + CGFloat(c) * (keyWidth + keySpacing)
                let y = contentRect.minY + CGFloat(r) * (keyHeight + keySpacing)
                let rect = CGRect(x: x, y: y, width: keyWidth, height: keyHeight)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: keyCornerRadius)
                let layer = CAShapeLayer()
                layer.path = path.cgPath
                layer.fillColor = UIColor.tertiarySystemBackground.cgColor
                layer.strokeColor = UIColor.separator.cgColor
                layer.lineWidth = 1 / UIScreen.main.scale
                self.layer.addSublayer(layer)
                keyLayers.append(layer)
            }
        }
    }
}


