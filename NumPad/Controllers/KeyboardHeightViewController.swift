//
//  KeyboardHeightViewController.swift
//  NumPad
//
//  A settings page that lets the user adjust the keyboard height using a slider.
//  It shows a text area so the user can bring up the keyboard and see live updates
//  while sliding. Height is persisted in the shared app group so the keyboard
//  extension can apply it immediately via SettingsSync notifications.
//

import UIKit

final class KeyboardHeightViewController: UIViewController {
    private let valueLabel = UILabel()
    private let slider = UISlider()
    private let textView = UITextView()
    private let infoLabel = UILabel()
    private let preview = KeyboardPreviewView()
    private var previewHeightConstraint: NSLayoutConstraint?

    private var minHeight: CGFloat = 220
    private var maxHeight: CGFloat = 440

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Keyboard Height"
        view.backgroundColor = .systemBackground

        configureViews()
        layoutViews()
        recalcLimitsAndApplyCurrent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        recalcLimitsAndApplyCurrent()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        recalcLimitsAndApplyCurrent()
    }

    private func configureViews() {
        valueLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        valueLabel.textAlignment = .center

        slider.minimumValue = 100
        slider.maximumValue = 400
        slider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderTouchEnded(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        // Replace real text input with a visual preview in Option 4
        textView.isHidden = true

        // Preview area (non-interactive)
        preview.layer.cornerRadius = 12

        // Instruction text below the slider
        infoLabel.text = "Drag the slider to preview the keyboard height. The preview at the bottom shows where the keyboard appears. Release the slider to apply the new height to the NumPad keyboard."
        infoLabel.textAlignment = .center
        infoLabel.textColor = .secondaryLabel
        infoLabel.font = .systemFont(ofSize: 13)
        infoLabel.numberOfLines = 0
    }

    private func layoutViews() {
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        slider.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        preview.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(valueLabel)
        view.addSubview(slider)
        view.addSubview(textView)
        view.addSubview(infoLabel)
        view.addSubview(preview)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            valueLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16),
            valueLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            valueLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),

            slider.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 12),
            slider.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            slider.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),

            infoLabel.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 10),
            infoLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            infoLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),

            preview.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            preview.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            preview.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -8),
            infoLabel.bottomAnchor.constraint(lessThanOrEqualTo: preview.topAnchor, constant: -8)
        ])

        // Adjustable height constraint for the preview
        let defaultHeight: CGFloat = 260
        previewHeightConstraint = preview.heightAnchor.constraint(equalToConstant: defaultHeight)
        previewHeightConstraint?.isActive = true
    }

    private func recalcLimitsAndApplyCurrent() {
        let isCompact = traitCollection.verticalSizeClass == .compact
        let isPad = traitCollection.userInterfaceIdiom == .pad
        let containerHeight = view.window?.bounds.height ?? UIScreen.main.bounds.height
        let minH: CGFloat = isCompact ? 160 : 220
        let maxFraction: CGFloat = isPad ? 0.66 : 0.5
        var maxH: CGFloat = floor(containerHeight * maxFraction)
        if maxH < minH { maxH = minH }
        minHeight = minH
        maxHeight = maxH

        slider.minimumValue = Float(minHeight)
        slider.maximumValue = Float(maxHeight)
        let current = currentHeightOrDefault()
        slider.setValue(Float(current), animated: false)
        updateValueLabel(height: current)
        // Do not apply to keyboard until user releases; preview reflects instantly
        // Reflect in preview
        previewHeightConstraint?.constant = clamped(current)
        preview.setNeedsLayout()
    }

    private func currentHeightOrDefault() -> CGFloat {
        let isCompact = traitCollection.verticalSizeClass == .compact
        let stored = isCompact ? CGFloat(UserPrefs.keyboardHeightCompactValue) : CGFloat(UserPrefs.keyboardHeightRegularValue)
        if stored > 0 { return clamped(stored) }
        // Default to mid-range
        return (minHeight + maxHeight) / 2
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        return max(minHeight, min(maxHeight, value))
    }

    @objc private func sliderChanged(_ sender: UISlider) {
        let height = clamped(CGFloat(sender.value))
        updateValueLabel(height: height)
        // Update preview only; commit on touch end
        previewHeightConstraint?.constant = height
        preview.setNeedsLayout()
        preview.layoutIfNeeded()
    }

    @objc private func sliderTouchEnded(_ sender: UISlider) {
        let height = clamped(CGFloat(sender.value))
        // Ensure final value is persisted and applied
        previewHeightConstraint?.constant = height
        applyHeight(height, notifyKeyboard: true)
    }

    // No Done button; application occurs on slider release

    private func updateValueLabel(height: CGFloat) {
        let pct = (height - minHeight) / (maxHeight - minHeight)
        let pctText = String(format: "%.0f%%", pct * 100)
        valueLabel.text = "Height: \(Int(height)) pt  (\(pctText) of range)"
        print("[App][Height] slider=\(height) range=[\(minHeight), \(maxHeight)] live=\(UserPrefs.liveKeyboardHeightAdjustEnabled)")
    }

    private func applyHeight(_ height: CGFloat, notifyKeyboard: Bool) {
        let isCompact = traitCollection.verticalSizeClass == .compact
        if isCompact {
            UserPrefs.keyboardHeightCompactValue = Double(height)
        } else {
            UserPrefs.keyboardHeightRegularValue = Double(height)
        }
        // Flush group defaults to disk so the keyboard extension sees the latest value immediately
        _ = UserDefaults.group.synchronize()
        if notifyKeyboard {
            SettingsSync.post()
        }
    }
}


