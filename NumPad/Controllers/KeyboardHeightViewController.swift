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

    private let segmentedControl = UISegmentedControl(items: [
        NSLocalizedString("Default", comment: "iPad keyboard height preset"),
        NSLocalizedString("Medium", comment: "iPad keyboard height preset"),
        NSLocalizedString("Large", comment: "iPad keyboard height preset")
    ])
    private let presetDescriptionLabel = UILabel()

    private var isPad: Bool { traitCollection.userInterfaceIdiom == .pad }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Keyboard Height", comment: "Keyboard height settings screen title")
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
        infoLabel.text = NSLocalizedString("Choose a keyboard size. The preview below shows the approximate keyboard height.", comment: "")
    }

    private func layoutIPhoneControls(guide: UILayoutGuide) {
        // Height adjustment is currently iPad-only. The iPhone slider is intentionally not shown:
        // the keyboard extension ignores custom heights on iPhone, so a live slider would be a
        // silent no-op. We explain that here and keep the preview at the system default size.
        slider.isHidden = true
        segmentedControl.isHidden = true
        presetDescriptionLabel.isHidden = true

        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 16)
        ])

        valueLabel.text = nil
        infoLabel.text = NSLocalizedString("Keyboard height adjustment is currently available on iPad only. On iPhone, NumPad uses the standard system keyboard height.", comment: "")
    }

    // MARK: - State

    private func recalcLimitsAndApplyCurrent() {
        let containerHeight = view.window?.bounds.height ?? UIScreen.main.bounds.height

        if isPad {
            recalcIPad(containerHeight: containerHeight)
        } else {
            // iPhone: adjustment unavailable — show an approximate system-default preview.
            previewHeightConstraint?.constant = floor(containerHeight * 0.25)
            preview.setNeedsLayout()
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
            valueLabel.text = String(format: NSLocalizedString("Default  (~%d%% of screen)", comment: ""), pctOfScreen)
            presetDescriptionLabel.text = NSLocalizedString("Standard system keyboard height. Buttons are the default size.", comment: "")
        case 1:
            valueLabel.text = String(format: NSLocalizedString("Medium  (%d%% of screen, %d pt)", comment: ""), pctOfScreen, Int(height))
            presetDescriptionLabel.text = NSLocalizedString("Larger keys that are easier to tap. Good for everyday use.", comment: "")
        case 2:
            valueLabel.text = String(format: NSLocalizedString("Large  (%d%% of screen, %d pt)", comment: ""), pctOfScreen, Int(height))
            presetDescriptionLabel.text = NSLocalizedString("Maximum size — the keyboard fills half the display. Great for accessibility.", comment: "")
        default:
            valueLabel.text = ""
            presetDescriptionLabel.text = ""
        }
    }

    @objc private func presetChanged(_ sender: UISegmentedControl) {
        let preset = sender.selectedSegmentIndex
        UserPrefs.iPadHeightPreset = preset
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

    // MARK: iPhone slider logic (reserved)
    //
    // The methods below implement a continuous iPhone height slider. iPhone height adjustment is
    // currently disabled (see `layoutIPhoneControls`) because the keyboard extension ignores custom
    // heights on iPhone. They are retained, unused, for when iPhone support is re-enabled.

    private func recalcIPhone(containerHeight: CGFloat) {
        let isCompact = traitCollection.verticalSizeClass == .compact
        // Height limits validated for 2024-2025 device lineup (iPhone mini through Pro Max):
        // - Portrait min 220pt: 4pt above system ~216pt on standard devices, below ~226pt on large devices
        // - Landscape min 160pt: 2pt below system ~162pt, provides flexibility
        // - Max 50% of container: 406-478pt depending on device, reasonable accessibility ceiling
        // These values must match between KeyboardViewController.heightLimits() and
        // KeyboardHeightViewController.recalcIPhone() to ensure slider range matches keyboard range.
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
        // Use system default captured by keyboard extension, fall back to reasonable estimate
        let systemDefault = CGFloat(UserPrefs.systemDefaultHeight)
        if systemDefault > 0 { return clamped(systemDefault) }
        // Final fallback: approximate system keyboard height if no data available yet
        // (user hasn't opened the keyboard since installing the update)
        return clamped(isCompact ? 162 : 216)
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
        SettingsSync.post()
    }
}
