//
//  KeyboardHeightViewController.swift
//  NumPad
//
//  A settings page that lets the user adjust the keyboard height.
//  On iPad it shows three presets (Default / Medium / Large).
//  On iPhone it shows a continuous slider.
//  Height is persisted in the shared app group so the keyboard
//  extension can apply it immediately via SettingsSync notifications.
//

import UIKit

final class KeyboardHeightViewController: UIViewController {

    // MARK: - Shared views

    private let valueLabel = UILabel()
    private let infoLabel = UILabel()
    private let preview = KeyboardPreviewView()
    private var previewHeightConstraint: NSLayoutConstraint?

    // MARK: - iPhone-only (slider)

    private let slider = UISlider()
    private var minHeight: CGFloat = 220
    private var maxHeight: CGFloat = 440

    // MARK: - iPad-only (segmented presets)

    private let segmentedControl = UISegmentedControl(items: ["Default", "Medium", "Large"])
    private let presetDescriptionLabel = UILabel()

    private var isPad: Bool { traitCollection.userInterfaceIdiom == .pad }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Keyboard Height"
        view.backgroundColor = .systemBackground

        configureViews()
        layoutViews()
        recalcLimitsAndApplyCurrent()

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitVerticalSizeClass.self, UITraitHorizontalSizeClass.self]) { (self: KeyboardHeightViewController, _) in
                self.recalcLimitsAndApplyCurrent()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        recalcLimitsAndApplyCurrent()
    }

    // Fallback for iOS 14-16
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #unavailable(iOS 17.0) {
            recalcLimitsAndApplyCurrent()
        }
    }

    // MARK: - Setup

    private func configureViews() {
        valueLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        valueLabel.textAlignment = .center

        infoLabel.textAlignment = .center
        infoLabel.textColor = .secondaryLabel
        infoLabel.font = .systemFont(ofSize: 13)
        infoLabel.numberOfLines = 0

        preview.layer.cornerRadius = 12

        // iPhone slider
        slider.minimumValue = 100
        slider.maximumValue = 400
        slider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderTouchEnded(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        // iPad segmented control
        segmentedControl.addTarget(self, action: #selector(presetChanged(_:)), for: .valueChanged)

        presetDescriptionLabel.textAlignment = .center
        presetDescriptionLabel.textColor = .secondaryLabel
        presetDescriptionLabel.font = .systemFont(ofSize: 14)
        presetDescriptionLabel.numberOfLines = 0
    }

    private func layoutViews() {
        let guide = view.safeAreaLayoutGuide

        // Common views
        for v: UIView in [valueLabel, infoLabel, preview] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }

        NSLayoutConstraint.activate([
            valueLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16),
            valueLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            valueLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),

            preview.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            preview.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            preview.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -8),

            infoLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            infoLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            infoLabel.bottomAnchor.constraint(lessThanOrEqualTo: preview.topAnchor, constant: -8)
        ])

        let defaultPreviewHeight: CGFloat = 260
        previewHeightConstraint = preview.heightAnchor.constraint(equalToConstant: defaultPreviewHeight)
        previewHeightConstraint?.isActive = true

        if isPad {
            layoutIPadControls(guide: guide)
        } else {
            layoutIPhoneControls(guide: guide)
        }
    }

    private func layoutIPadControls(guide: UILayoutGuide) {
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        presetDescriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)
        view.addSubview(presetDescriptionLabel)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 20),
            segmentedControl.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 40),
            segmentedControl.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -40),

            presetDescriptionLabel.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            presetDescriptionLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            presetDescriptionLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),

            infoLabel.topAnchor.constraint(equalTo: presetDescriptionLabel.bottomAnchor, constant: 10)
        ])

        slider.isHidden = true
        infoLabel.text = "Choose a keyboard size. The preview below shows the approximate keyboard height."
    }

    private func layoutIPhoneControls(guide: UILayoutGuide) {
        slider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(slider)

        NSLayoutConstraint.activate([
            slider.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 12),
            slider.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            slider.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),

            infoLabel.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 10)
        ])

        segmentedControl.isHidden = true
        presetDescriptionLabel.isHidden = true
        infoLabel.text = "Drag the slider to preview the keyboard height. The preview at the bottom shows where the keyboard appears. Release the slider to apply the new height to the NumPad keyboard."
    }

    // MARK: - State

    private func recalcLimitsAndApplyCurrent() {
        let containerHeight = view.window?.bounds.height ?? UIScreen.main.bounds.height

        if isPad {
            recalcIPad(containerHeight: containerHeight)
        } else {
            recalcIPhone(containerHeight: containerHeight)
        }
    }

    // MARK: iPad preset logic

    private static let presetFractions: [CGFloat] = [0.0, 0.35, 0.50]  // 0 means system default

    private func recalcIPad(containerHeight: CGFloat) {
        let preset = UserPrefs.iPadHeightPreset
        segmentedControl.selectedSegmentIndex = max(0, min(2, preset))

        let previewHeight = heightForIPadPreset(preset, containerHeight: containerHeight)
        previewHeightConstraint?.constant = previewHeight
        preview.setNeedsLayout()

        updateIPadLabels(preset: preset, height: previewHeight, containerHeight: containerHeight)
    }

    private func heightForIPadPreset(_ preset: Int, containerHeight: CGFloat) -> CGFloat {
        switch preset {
        case 1: return floor(containerHeight * 0.35)
        case 2: return floor(containerHeight * 0.50)
        default:
            // System default: approximate as ~25% of screen for preview purposes
            return floor(containerHeight * 0.25)
        }
    }

    private func updateIPadLabels(preset: Int, height: CGFloat, containerHeight: CGFloat) {
        let pctOfScreen = Int(round(height / containerHeight * 100))
        switch preset {
        case 0:
            valueLabel.text = "Default  (~\(pctOfScreen)% of screen)"
            presetDescriptionLabel.text = "Standard system keyboard height. Buttons are the default size."
        case 1:
            valueLabel.text = "Medium  (\(pctOfScreen)% of screen, \(Int(height)) pt)"
            presetDescriptionLabel.text = "Larger keys that are easier to tap. Good for everyday use."
        case 2:
            valueLabel.text = "Large  (\(pctOfScreen)% of screen, \(Int(height)) pt)"
            presetDescriptionLabel.text = "Maximum size — the keyboard fills half the display. Great for accessibility."
        default:
            valueLabel.text = ""
            presetDescriptionLabel.text = ""
        }
    }

    @objc private func presetChanged(_ sender: UISegmentedControl) {
        let preset = sender.selectedSegmentIndex
        UserPrefs.iPadHeightPreset = preset
        UserDefaults.group.synchronize()
        SettingsSync.post()

        let containerHeight = view.window?.bounds.height ?? UIScreen.main.bounds.height
        let previewHeight = heightForIPadPreset(preset, containerHeight: containerHeight)
        previewHeightConstraint?.constant = previewHeight
        updateIPadLabels(preset: preset, height: previewHeight, containerHeight: containerHeight)

        UIView.animate(withDuration: 0.25) {
            self.preview.setNeedsLayout()
            self.preview.layoutIfNeeded()
            self.view.layoutIfNeeded()
        }

        Analytics.logEvent(name: "ipad_height_preset", attributes: [Analytics.ParameterValue: preset])
    }

    // MARK: iPhone slider logic

    private func recalcIPhone(containerHeight: CGFloat) {
        let isCompact = traitCollection.verticalSizeClass == .compact
        let minH: CGFloat = isCompact ? 160 : 220
        let maxFraction: CGFloat = 0.5
        var maxH: CGFloat = floor(containerHeight * maxFraction)
        if maxH < minH { maxH = minH }
        minHeight = minH
        maxHeight = maxH

        slider.minimumValue = Float(minHeight)
        slider.maximumValue = Float(maxHeight)
        let current = currentHeightOrDefault()
        slider.setValue(Float(current), animated: false)
        updateIPhoneValueLabel(height: current)
        previewHeightConstraint?.constant = clamped(current)
        preview.setNeedsLayout()
    }

    private func currentHeightOrDefault() -> CGFloat {
        let isCompact = traitCollection.verticalSizeClass == .compact
        let stored = isCompact ? CGFloat(UserPrefs.keyboardHeightCompactValue) : CGFloat(UserPrefs.keyboardHeightRegularValue)
        if stored > 0 { return clamped(stored) }
        return (minHeight + maxHeight) / 2
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        return max(minHeight, min(maxHeight, value))
    }

    private func updateIPhoneValueLabel(height: CGFloat) {
        let pct = (height - minHeight) / (maxHeight - minHeight)
        let pctText = String(format: "%.0f%%", pct * 100)
        valueLabel.text = "Height: \(Int(height)) pt  (\(pctText) of range)"
    }

    @objc private func sliderChanged(_ sender: UISlider) {
        let height = clamped(CGFloat(sender.value))
        updateIPhoneValueLabel(height: height)
        previewHeightConstraint?.constant = height
        preview.setNeedsLayout()
        preview.layoutIfNeeded()
    }

    @objc private func sliderTouchEnded(_ sender: UISlider) {
        let height = clamped(CGFloat(sender.value))
        previewHeightConstraint?.constant = height
        applyIPhoneHeight(height)
    }

    private func applyIPhoneHeight(_ height: CGFloat) {
        let isCompact = traitCollection.verticalSizeClass == .compact
        if isCompact {
            UserPrefs.keyboardHeightCompactValue = Double(height)
        } else {
            UserPrefs.keyboardHeightRegularValue = Double(height)
        }
        // Flush to disk so the keyboard extension (separate process) reads the
        // new value before the Darwin notification arrives.
        UserDefaults.group.synchronize()
        SettingsSync.post()
    }
}
