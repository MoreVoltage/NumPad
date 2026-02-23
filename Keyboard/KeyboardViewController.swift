//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import MobileCoreServices

class KeyboardViewController: UIInputViewController, UIInputViewAudioFeedback {
    private var clipboardView: ClipboardHistoryView?
    private var snippetsView: SnippetsListView?
    private var taxTipView: TaxTipView?
    
    private var heightConstraint: NSLayoutConstraint?
    private var stackViewTopConstraint: NSLayoutConstraint?
    
    
    lazy var stackView: StackView = { [unowned self] in
        let stackView = StackView()
        stackView.backgroundColor = KeyboardTheme.scheme.border
        stackView.addGestureRecognizer({
            let gesture = UIPanGestureRecognizer(target: self, action: #selector(panned))
            gesture.maximumNumberOfTouches = 1
            return gesture
        }())
        guard let container = self.inputView else { return stackView }
        container.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        let leading = stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        let trailing = stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        let bottom = stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        let top = stackView.topAnchor.constraint(equalTo: container.topAnchor)
        NSLayoutConstraint.activate([leading, trailing, bottom, top])
        self.stackViewTopConstraint = top
        return stackView
    }()
    
    lazy var items: [[Item]] = self.makeItems()
    
    var maxWidth: CGFloat {
        guard let bounds = self.inputView?.bounds, !bounds.isEmpty else { return UIScreen.main.bounds.width }
        return bounds.width
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Enable self-sizing so iOS respects our height constraint on iPhone
        if let iv = inputView as? UIInputView {
            iv.allowsSelfSizing = true
        }

        reloadItems()
        runAnalytics()
        // Listen for settings changes from the container app and refresh keyboard immediately
        SettingsSync.observe(self) { [weak self] in
            guard let self = self else { return }
            // Re-read shared defaults from disk; the container app may have
            // written new values that our in-memory cache hasn't picked up yet.
            UserDefaults.group.synchronize()
            self.reloadItems()
            self.updateAdjustableHeightFeatureState()
            // Live height value (ephemeral) takes precedence when present
            let live = UserPrefs.currentKeyboardHeightLive
            if live > 0 {
                self.ensureHeightConstraintExists()
                let proposed = CGFloat(live)
                let clamped = self.clampedHeight(for: proposed)
                if self.heightConstraint?.constant != clamped {
                    self.heightConstraint?.constant = clamped
                    self.persistHeight(clamped) // keep persisted in sync while dragging
                    self.view.setNeedsLayout()
                    self.view.layoutIfNeeded() // force immediate visual update
                }
            } else if UserPrefs.isKeyboardHeightLiveAdjusting {
                // If live adjusting flag is set but we received 0, re-apply persisted value to fight host resets
                self.ensureHeightConstraintExists()
                if let restored = self.restoredHeightIfAny() {
                    let clamped = self.clampedHeight(for: restored)
                    if self.heightConstraint?.constant != clamped {
                        self.heightConstraint?.constant = clamped
                        self.view.setNeedsLayout()
                        self.view.layoutIfNeeded()
                    }
                }
            }
        }

        // Low-latency live height listener
        NPLiveHeightMessenger.observe(self) { [weak self] msg in
            guard let self = self else { return }
            UserDefaults.group.synchronize()
            guard UserPrefs.liveKeyboardHeightAdjustEnabled else { return }
            self.ensureHeightConstraintExists()
            let proposed = CGFloat(msg.height)
            let clamped = self.clampedHeight(for: proposed)
            if self.heightConstraint?.constant != clamped {
                self.heightConstraint?.constant = clamped
                self.persistHeight(clamped)
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
            }
        }
    }

    // Apple's recommended place to set keyboard height — called at the right
    // point in the layout cycle so the system respects our constraint.
    override func updateViewConstraints() {
        super.updateViewConstraints()
        ensureHeightConstraintExists()
        if let restored = restoredHeightIfAny() {
            heightConstraint?.constant = clampedHeight(for: restored)
        }
    }

    // Re-assert height after layout passes where the system may have reset it
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let hc = heightConstraint, let restored = restoredHeightIfAny() {
            let clamped = clampedHeight(for: restored)
            if hc.constant != clamped {
                hc.constant = clamped
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self = self else { return }
            self.reloadItems()
            self.ensureHeightConstraintExists()
            self.clampHeightToBounds()
        }, completion: { _ in })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ensureHeightConstraintExists()
        if let restored = restoredHeightIfAny() {
            heightConstraint?.constant = clampedHeight(for: restored)
            view.setNeedsLayout()
        }
    }
    
    deinit {
        SettingsSync.remove(self)
        NPLiveHeightMessenger.remove(self)
    }
    
    @IBAction func longPressed(sender: UIButton) {
        guard self.textDocumentProxy.hasText else { return }
        self.textDocumentProxy.deleteBackward()
        playClick()
    }
    
    @IBAction func panned(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .changed, .ended:
            let point = recognizer.location(in: recognizer.view)
            for cell in stackView.cells {
                let frame = cell.convert(cell.bounds, to: stackView)
                let containsPoint = frame.contains(point)
                switch recognizer.state {
                case .changed:
                    cell._isHighlighted = containsPoint
                case .ended where containsPoint:
                    cell.sendActions(for: .touchUpInside)
                    fallthrough
                default:
                    cell._isHighlighted = false
                }
            }
        default: break
        }
    }
    
    func reloadItems() {
        items = makeItems()
        stackView.configure(items, keyboardType: .selected, roundedCorners: Keyboard.hasRoundedCorners, grid: Keyboard.hasGrid, width: maxWidth, block: { [weak self] (position, item, cell) in
            guard let self = self else { return }
            switch (item.title, item.imageName) {
            case (_, "next"?):
                // Optionally repurpose the Next key to cycle keyboard types instead of system globe
                if UserPrefs.repurposeNextKey {
                    cell.removeTarget(nil, action: nil, for: .allEvents)
                    cell.addTarget(self, action: #selector(self.cycleKeyboardType), for: .touchUpInside)
                } else {
                    cell.addTarget(self, action: #selector(handleInputModeList), for: .allTouchEvents)
                }
            case (_, "back"?):
                cell.addTarget(self, action: #selector(longPressed), forContinuousPressWithTimeInterval: 0.1)
            case ("0"?, _):
                let longPress = UILongPressGestureRecognizer(target: self, action: #selector(showClipboardHistory(_:)))
                longPress.minimumPressDuration = 0.35
                cell.addGestureRecognizer(longPress)
            case ("."?, _):
                let longPress = UILongPressGestureRecognizer(target: self, action: #selector(showSnippets(_:)))
                longPress.minimumPressDuration = 0.35
                cell.addGestureRecognizer(longPress)
            case ("%"?, _):
                let longPress = UILongPressGestureRecognizer(target: self, action: #selector(showTaxTip(_:)))
                longPress.minimumPressDuration = 0.35
                cell.addGestureRecognizer(longPress)
            default: break
            }
        }, touchDown: { [weak self] (position, item) in self?.touchDown(position) }, tapped: { [weak self] (position, item) in self?.tapped(position) })
    }

    // MARK: - UIInputViewAudioFeedback
    var enableInputClicksWhenVisible: Bool { true }
    
}

// MARK: - Helpers
private extension KeyboardViewController {
    func updateAdjustableHeightFeatureState() {
        ensureHeightConstraintExists()
        clampHeightToBounds()
        if let restored = restoredHeightIfAny() {
            let newHeight = clampedHeight(for: restored)
            heightConstraint?.constant = newHeight
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }
    }

    func ensureHeightConstraintExists() {
        // iPad default preset: remove custom height and let the system size the keyboard
        if traitCollection.userInterfaceIdiom == .pad && UserPrefs.iPadHeightPreset == 0 {
            heightConstraint?.isActive = false
            heightConstraint = nil
            return
        }

        // Recreate if the constraint was deactivated by the system (reference
        // is non-nil but the constraint is no longer active in the layout engine).
        if let hc = heightConstraint, !hc.isActive {
            heightConstraint = nil
        }

        if heightConstraint == nil {
            // Prefer the persisted height so a returning keyboard immediately
            // adopts the user's chosen size instead of the system default.
            let initial: CGFloat
            if let restored = restoredHeightIfAny() {
                initial = restored
            } else {
                let currentHeight = (inputView?.bounds.height ?? view.bounds.height)
                initial = currentHeight > 0 ? currentHeight : 300
            }
            heightConstraint = (inputView ?? view).heightAnchor.constraint(equalToConstant: clampedHeight(for: initial))
            // Priority 999 overrides the system's height constraint (~999) on iPhone
            // while avoiding unsatisfiable-constraint errors that .required (1000) causes
            heightConstraint?.priority = UILayoutPriority(rawValue: 999)
            heightConstraint?.isActive = true
        }
    }

    func clampedHeight(for proposed: CGFloat) -> CGFloat {
        let limits = heightLimits()
        return max(limits.min, min(limits.max, proposed))
    }

    func clampHeightToBounds() {
        if let hc = heightConstraint {
            hc.constant = clampedHeight(for: hc.constant)
        }
    }

    func heightLimits() -> (min: CGFloat, max: CGFloat) {
        let isCompact = traitCollection.verticalSizeClass == .compact
        let isPad = traitCollection.userInterfaceIdiom == .pad
        let containerHeight = view.window?.bounds.height ?? inputView?.superview?.bounds.height ?? UIScreen.main.bounds.height
        // Reasonable minimums similar to system keyboards
        let minH: CGFloat = isCompact ? 160 : 220
        // iPad caps at 50% (matching the large preset); iPhone at 50%
        let maxFraction: CGFloat = isPad ? 0.50 : 0.5
        var maxH: CGFloat = floor(containerHeight * maxFraction)
        // Ensure max is never below min
        if maxH < minH { maxH = minH }
        return (minH, maxH)
    }

    func persistHeight(_ height: CGFloat) {
        let isCompact = traitCollection.verticalSizeClass == .compact
        if isCompact {
            UserPrefs.keyboardHeightCompactValue = Double(height)
        } else {
            UserPrefs.keyboardHeightRegularValue = Double(height)
        }
    }

    func restoredHeightIfAny() -> CGFloat? {
        // iPad presets: compute height dynamically from screen size
        if traitCollection.userInterfaceIdiom == .pad {
            let preset = UserPrefs.iPadHeightPreset
            guard preset > 0 else { return nil } // preset 0 = system default
            let screenHeight = view.window?.bounds.height ?? UIScreen.main.bounds.height
            switch preset {
            case 1: return floor(screenHeight * 0.35) // medium
            case 2: return floor(screenHeight * 0.50) // large
            default: return nil
            }
        }
        // iPhone: use stored pixel values
        let isCompact = traitCollection.verticalSizeClass == .compact
        let value = isCompact ? UserPrefs.keyboardHeightCompactValue : UserPrefs.keyboardHeightRegularValue
        return value > 0 ? CGFloat(value) : nil
    }
    
    func touchDown(_ position: Position) {
        playClick()
    }
    
    func tapped(_ position: Position) {
        let item = items[position.0][position.1]
        // If Tax/Tip overlay is visible, route numeric input to the overlay instead of the host app
        if let taxView = taxTipView {
            switch (item.title, item.imageName) {
            case (let title?, _) where ["0","1","2","3","4","5","6","7","8","9","."].contains(title):
                taxView.append(title)
                return
            case (_, "back"?):
                taxView.deleteBackward()
                return
            case (String.enter?, _):
                // Compute and insert when Enter is tapped
                taxView.apply()
                return
            default:
                break
            }
        }
        switch (item.title, item.imageName) {
        case (String.space?, _): self.textDocumentProxy.insertText(" ")
        case (String.enter?, _): self.textDocumentProxy.insertText("\n")
        case (_, "next"?): self.advanceToNextInputMode()
        case (_, "back"?): self.textDocumentProxy.deleteBackward()
        case (_, "math"?), (_, "math2"?): KeyboardType.selected.toggleMath(); reloadItems()
        case (let title?, _) where Monetization.paywallEnabled && !Monetization.isProEntitled && ["%", "$", "€", "£", "¥"].contains(title):
            // Deep-link to Store when locked key pressed
            if let url = URL(string: "numpad://store-preview") {
                self.extensionContext?.open(url, completionHandler: nil)
            }
        default: item.title.map(self.textDocumentProxy.insertText)
        }
        sendAnalytics(item: item)
    }
    
    func playClick() {
        guard hasFullAccess else { return }
        if UserPrefs.soundEnabled {
            UIDevice.current.playInputClick()
        }
    }
    
    func runAnalytics() {
        guard hasFullAccess else { return }
        Analytics.start
    }
    
    func sendAnalytics(item: Item) {
        guard hasFullAccess else { return }
        (item.title ?? item.imageName).map {
            Analytics.logEvent(name: "clicked", attributes: [Analytics.ParameterValue: $0])
        }
    }
    
    func makeItems() -> [[Item]] {
        let items = Item.all(type: .selected)
        let isReversed = self.view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        return isReversed ? items.map { $0.reversed() } : items
    }
    
    @objc func cycleKeyboardType() {
        // Cycle through packs including default
        let all: [KeyboardType] = [.default] + KeyboardType.packs
        if let idx = all.firstIndex(of: KeyboardType.selected) {
            let next = all[(idx + 1) % all.count]
            KeyboardType.selected = next
        } else {
            KeyboardType.selected = .default
        }
        reloadItems()
    }
    
}

// MARK: - Clipboard overlay
extension KeyboardViewController: ClipboardHistoryViewDelegate {
    /// Capture the current system pasteboard item into clipboard history (if new and non-empty).
    /// On iOS 16+, reading UIPasteboard.general.string triggers a system permission banner.
    /// If the user denies, `string` returns nil and we gracefully fall back to existing history.
    private func captureCurrentPasteboardItem() {
        guard hasFullAccess else { return }
        if let text = UIPasteboard.general.string, !text.isEmpty {
            ClipboardHistoryManager.shared.add(text)
        }
    }

    @objc func showClipboardHistory(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        guard clipboardView == nil, let container = self.inputView else { return }
        captureCurrentPasteboardItem()
        let view = ClipboardHistoryView()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        let horizontalInset: CGFloat = 10
        let heightMultiplier: CGFloat = 0.6
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: horizontalInset),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -horizontalInset),
            view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            view.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: heightMultiplier)
        ])
        clipboardView = view
    }

    func clipboardHistoryView(_ view: ClipboardHistoryView, didSelectItem item: String) {
        self.textDocumentProxy.insertText(item)
        clipboardView?.removeFromSuperview()
        clipboardView = nil
    }

    func clipboardHistoryViewDidRequestClose(_ view: ClipboardHistoryView) {
        clipboardView?.removeFromSuperview()
        clipboardView = nil
    }
}

// MARK: - Snippets overlay
extension KeyboardViewController: SnippetsListViewDelegate {
    @objc func showSnippets(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        guard snippetsView == nil, let container = self.inputView else { return }
        let view = SnippetsListView()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            view.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.6)
        ])
        snippetsView = view
    }

    func snippetsListView(_ view: SnippetsListView, didSelectText text: String) {
        self.textDocumentProxy.insertText(text)
        snippetsView?.removeFromSuperview()
        snippetsView = nil
    }
    func snippetsListViewDidRequestClose(_ view: SnippetsListView) {
        snippetsView?.removeFromSuperview()
        snippetsView = nil
    }
}

// MARK: - Tax/Tip overlay
extension KeyboardViewController: TaxTipViewDelegate {
    @objc func showTaxTip(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        guard taxTipView == nil, let container = self.inputView else { return }
        let view = TaxTipView()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            view.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.5)
        ])
        taxTipView = view
    }

    func taxTipView(_ view: TaxTipView, didCompute value: String) {
        self.textDocumentProxy.insertText(value)
        taxTipView?.removeFromSuperview()
        taxTipView = nil
    }
    func taxTipViewDidRequestClose(_ view: TaxTipView) {
        taxTipView?.removeFromSuperview()
        taxTipView = nil
    }
}
