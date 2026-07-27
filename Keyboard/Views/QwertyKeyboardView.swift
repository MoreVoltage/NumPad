import UIKit

protocol QwertyKeyboardViewDelegate: AnyObject {
    func qwertyKeyboardView(_ view: QwertyKeyboardView, didTap key: QwertyKey)
    /// Called once per button as rows are (re)built, so the controller can attach
    /// gesture-level behavior (globe input-mode list, backspace autorepeat).
    func qwertyKeyboardView(_ view: QwertyKeyboardView,
                            didCreate button: QwertyKeyButton,
                            for key: QwertyKey)
    /// Fired once on touch-down (not on repeat ticks) for click/haptic parity with the numpad.
    func qwertyKeyboardView(_ view: QwertyKeyboardView, didTouchDown key: QwertyKey)
    /// A layout pass resolved a different device/layout context. The page host uses this to
    /// swap to the matching touch-personalization model before the next tap.
    func qwertyKeyboardView(_ view: QwertyKeyboardView,
                            didResolveLayoutMode mode: QwertyLayoutMode)
}

private final class QwertyAlternateCalloutView: UIView {
    let itemWidth: CGFloat

    private var selection: QwertyAlternateSelection
    private let labels: [UILabel]

    init(values: [String], itemWidth: CGFloat) {
        self.itemWidth = itemWidth
        selection = QwertyAlternateSelection(values: values, itemWidth: itemWidth)
        labels = values.map { value in
            let label = UILabel()
            label.text = value
            label.font = .systemFont(ofSize: 24)
            label.textAlignment = .center
            label.isAccessibilityElement = true
            label.accessibilityLabel = String(
                format: NSLocalizedString("Alternate %@", comment: "alternate callout item"),
                value
            )
            label.accessibilityTraits = .button
            return label
        }
        super.init(frame: .zero)
        let palette = QwertyThemePalette.palette(for: KeyboardTheme.selectedOrAutomatic)
        backgroundColor = palette.plainFill
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = palette.background.withAlphaComponent(0.45).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)
        labels.forEach(addSubview)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        for (index, label) in labels.enumerated() {
            label.frame = CGRect(x: CGFloat(index) * itemWidth,
                                 y: 0,
                                 width: itemWidth,
                                 height: bounds.height)
        }
    }

    @discardableResult
    func updateHighlight(horizontalLocation: CGFloat) -> String? {
        let value = selection.update(horizontalLocation: horizontalLocation)
        let palette = QwertyThemePalette.palette(for: KeyboardTheme.selectedOrAutomatic)
        for label in labels {
            let highlighted = label.text == value
            label.backgroundColor = highlighted ? palette.specialFill : .clear
            label.accessibilityTraits = highlighted ? [.button, .selected] : .button
        }
        return value
    }

    func releaseSelection() -> String? {
        selection.release()
    }
}

extension QwertyKeyboardViewDelegate {
    func qwertyKeyboardView(_ view: QwertyKeyboardView, didTouchDown key: QwertyKey) {}
    func qwertyKeyboardView(_ view: QwertyKeyboardView,
                            didResolveLayoutMode mode: QwertyLayoutMode) {}
}

/// Receives the completed glide path (view coordinates) when a glide gesture ends — the page
/// host wires this to the glide decoder (glide-and-accuracy design §4.3). A separate protocol
/// from `QwertyKeyboardViewDelegate` so the tap plumbing is untouched while glide ships dark.
protocol QwertyKeyboardViewGlideDelegate: AnyObject {
    func qwertyKeyboardView(_ view: QwertyKeyboardView, didCompleteGlide path: [CGPoint])
}

/// Renders the QWERTY grid with manual frame layout so key geometry comes *exactly* from
/// `QwertyLayout`'s unit widths — the pure model stays the single source of truth for the
/// parity spec (plan §0.1), and there is no Auto Layout drift to chase.
final class QwertyKeyboardView: UIView {

    private enum Metrics {
        static let edgeInset: CGFloat = 3
        static let topInset: CGFloat = 6
        static let bottomInset: CGFloat = 4

        /// Inter-key gap, both axes — identical derivation to the numpad's own
        /// `KeyMetrics.spacing(roundedCorners:grid:)` (`StackView.configure`), so the two
        /// pages' grids read as one design system rather than QWERTY's previous fixed,
        /// system-keyboard-style gap (owner note 3).
        static var keyGap: CGFloat {
            KeyMetrics.spacing(roundedCorners: Keyboard.hasRoundedCorners, grid: Keyboard.hasGrid)
        }
        static var rowGap: CGFloat { keyGap }

        /// How far outside the keyboard's own bounds `hitTest` may still claim a touch —
        /// enough to catch a real touch event reported a hair past an edge, small enough
        /// that a genuine tap on the sibling suggestion bar above always falls through.
        static let hitTestSlop: CGFloat = 4
    }

    /// Trail rendering knobs (glide-and-accuracy design §4.1's "lightweight fading polyline").
    private enum GlideTrail {
        static let lineWidth: CGFloat = 6
        static let strokeAlpha: CGFloat = 0.35
        static let fadeDuration: CFTimeInterval = 0.25
        /// Keeps the trail above every key layer regardless of subview order, even if the
        /// grid rebuilds mid-glide (new buttons are appended after existing sublayers).
        static let zPosition: CGFloat = 500
    }

    weak var delegate: QwertyKeyboardViewDelegate?
    weak var glideDelegate: QwertyKeyboardViewGlideDelegate?

    /// Label for the return key, mapped from the host field's `returnKeyType`.
    var returnKeyLabel = "return"

    /// Per-key-index bias for ambiguous gap touches, refreshed by the page host every time
    /// suggestions recompute (`QwertyTouchRouting.bias(forCompletions:currentWord:keyOutputs:)`)
    /// — consumed by `hitTest`. Reset whenever the grid is rebuilt (`configure`/`updateTopStrip`)
    /// since a new key set invalidates old indices; the host repopulates it on the very next
    /// suggestions refresh.
    var touchBias: [Int: CGFloat] = [:]

    /// Learned per-key touch offsets (`QwertyTouchPersonalization`, design §3) in view space,
    /// keyed by the same flattened key index as `touchBias` — consumed by `hitTest` during gap
    /// resolution only. Never set directly: derived from `normalizedTouchOffsets` against the
    /// CURRENT key frames on every layout pass, because view-space vectors go stale whenever
    /// key geometry changes (rotation, height preset, grid rebuild).
    private(set) var touchOffsets: [Int: CGVector] = [:]

    /// The layout-independent form the page host feeds via `rebuildTouchOffsets(from:)`: per
    /// flattened key index, the learned tap offset from the key center normalized by the key's
    /// width/height. Reset with `touchBias` on grid rebuilds (stale indices); the host
    /// repopulates it right after every rebuild and personalization flush.
    private var normalizedTouchOffsets: [Int: (dx: Double, dy: Double)] = [:]

    /// The most recent touch-down: which button and where inside the view the finger landed —
    /// the raw capture behind `lastTouchOffset(for:)`.
    private var lastTouchDown: (button: QwertyKeyButton, location: CGPoint)?

    private var rowLayouts: [QwertyRow] = []
    private var rowButtons: [[QwertyKeyButton]] = []
    /// Resolved fresh on every layout pass from current traits, actual available bounds, floating
    /// state, and the app-group/profile preference.
    private(set) var resolvedLayoutMode: QwertyLayoutMode = .automatic
    private(set) var layoutContentFrame: CGRect = .zero
    private var layoutHitRegions: [CGRect] = []
    private(set) var layoutSplitGap: CGRect?

    var personalizationContext: QwertyPersonalizationContext {
        QwertyPersonalizationContext.resolved(
            idiom: layoutTraits.userInterfaceIdiom,
            layoutMode: resolvedLayoutMode
        )
    }

    /// The trait environment that decides iPad geometry — the OWNING view controller's, not
    /// this view's own.
    ///
    /// A `UIView`'s `traitCollection` is only authoritative once UIKit has resolved the view
    /// inside a window, and it never picks up a container's
    /// `setOverrideTraitCollection(_:forChild:)`. Both cases are live here:
    /// `QwertyPageHost` primes the grid with a `containerView.layoutIfNeeded()` while the
    /// keyboard is still off-window (so the first pass — the one that seeds
    /// `resolvedLayoutMode` and therefore the touch-personalization model — read `.phone`
    /// full-width geometry on iPad), and the numpad page resolves ITS placement from
    /// `KeyboardViewController.traitCollection`. Reading the view controller's traits is the
    /// authority `QwertyPageHost` already uses for `verticalSizeClass`, and it keeps both
    /// pages of the extension on one trait environment instead of two that can disagree.
    private var layoutTraits: UITraitCollection {
        owningViewController?.traitCollection ?? traitCollection
    }

    /// Nearest view controller up the responder chain (this view's superview chain ends at
    /// some controller's root view, whose `next` is that controller). Nil for a bare view
    /// with no controller above it, which falls back to the view's own traits.
    private var owningViewController: UIViewController? {
        var responder: UIResponder? = next
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }

    /// The in-bounds magnified-key bubble (KeyboardKit-style). Apple blocks drawing above
    /// the extension's own top edge (technical doc §1), so this stays inside the keyboard
    /// view — and it's iPhone-only, because the native iPad keyboard shows no callouts.
    private let calloutLabel = UILabel()
    private var alternateCallout: QwertyAlternateCalloutView?

    /// The glide recognizer, present ONLY while the glide gate passes (see
    /// `updateGlideAvailability()`). Flag off ⇒ nil ⇒ byte-for-byte current touch behavior.
    private var glideRecognizer: QwertyGlideGestureRecognizer?

    /// The in-flight glide's polyline, rebuilt from the recognizer's points on `.changed`
    /// and faded out on end. Nil whenever no glide is being drawn.
    private var glideTrailLayer: CAShapeLayer?

    /// Token for the block-based VoiceOver status observer: a mid-session VoiceOver toggle
    /// must tear down / reinstall the glide recognizer LIVE (the gate in
    /// `updateGlideAvailability()` reads `UIAccessibility.isVoiceOverRunning`), not wait for
    /// the next grid rebuild or settings sync. Block-based observers are NOT removed
    /// automatically on dealloc — the token is kept for explicit removal in `deinit`.
    private var voiceOverObserver: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        calloutLabel.font = .systemFont(ofSize: 32)
        calloutLabel.textAlignment = .center
        calloutLabel.layer.cornerRadius = 8
        calloutLabel.layer.masksToBounds = true
        calloutLabel.isHidden = true
        addSubview(calloutLabel)
        applyTheme()
        voiceOverObserver = NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main) { [weak self] _ in
            self?.updateGlideAvailability()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        if let observer = voiceOverObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
        // Geometry is resolved in `layoutSubviews` from the trait environment, so a trait
        // change (window insertion resolving the idiom/size class for the first time, a
        // rotation, an iPad Slide Over resize) has to schedule a fresh pass — re-theming
        // alone would leave the keys in the previously resolved layout mode.
        setNeedsLayout()
    }

    /// Canvas color shown in the gaps between keys — the same tone `StackView`'s container
    /// shows behind the numpad's grid (`KeyboardTheme.scheme.border`), so a page switch never
    /// flashes a different backdrop underneath the keys (owner note 3).
    private func applyTheme() {
        backgroundColor = QwertyThemePalette.palette(for: KeyboardTheme.selectedOrAutomatic).background
    }

    // MARK: - Configuration

    /// Rebuilds the grid: the swappable top strip (number row / pack row) plus the current
    /// layer's rows.
    func configure(rows: [QwertyRow], topStrip: [QwertyKey]) {
        rowButtons.flatMap { $0 }.forEach { $0.removeFromSuperview() }
        rowLayouts = [QwertyRow(keys: topStrip)] + rows
        rowButtons = rowLayouts.map { row in
            row.keys.map { makeButton(for: $0) }
        }
        touchBias = [:]
        clearTouchOffsets()
        applyTheme()
        updateGlideAvailability()
        setNeedsLayout()
    }

    /// Swaps only the top strip (pack switch / number-line toggle) without touching the main
    /// key rows — no full-keyboard flash for a strip-only change.
    func updateTopStrip(_ keys: [QwertyKey]) {
        guard !rowLayouts.isEmpty else { return }
        rowButtons[0].forEach { $0.removeFromSuperview() }
        rowLayouts[0] = QwertyRow(keys: keys)
        rowButtons[0] = keys.map { makeButton(for: $0) }
        touchBias = [:]
        clearTouchOffsets()
        setNeedsLayout()
    }

    private func makeButton(for key: QwertyKey) -> QwertyKeyButton {
        let button = QwertyKeyButton(key: key)
        button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(captureTouchDown(_:event:)), for: .touchDown)
        if case .character = key.kind, key.width <= 1.45 {
            // Content keys get the magnified callout; wide keys (space, return) never do.
            button.addTarget(self, action: #selector(keyTouchDown(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(keyTouchEnded(_:)),
                             for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
        addSubview(button)
        decorate(button, for: key)
        delegate?.qwertyKeyboardView(self, didCreate: button, for: key)
        return button
    }

    // MARK: - Zero-dead-zone touch routing (owner note 4)

    /// Routes any touch landing in the visual gap between keys to the nearest key, so there is
    /// no point on the keyboard a press can miss. A direct hit on a button — or on the callout
    /// machinery already wired to it — passes through untouched; only a miss (the container
    /// itself, or `nil` for a touch reported a hair outside `bounds`) gets redirected, and it's
    /// redirected to the actual button object. Because UIKit then delivers the touch to that
    /// real button, every target/gesture already attached to it (long-press repeat on
    /// backspace, the space-bar cursor pan) fires exactly as it would on a direct hit.
    ///
    /// Routing stops at `Metrics.hitTestSlop` outside `bounds`: the container hit-tests this
    /// view BEFORE the suggestion bar sitting directly above it, so a point past the slop
    /// (a chip tap, converted to negative y here) must return the `super` verdict — never a
    /// clamped-to-the-top-edge key — or the bar's chips can never receive a touch.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        guard result == nil || result === self else { return result }
        let slop = Metrics.hitTestSlop
        guard bounds.insetBy(dx: -slop, dy: -slop).contains(point) else { return result }
        let buttons = rowButtons.flatMap { $0 }
        guard let index = routedKeyIndex(
            at: point,
            among: buttons,
            outerEdgeSlop: slop
        ) else { return result }
        return buttons[index]
    }

    /// The single routing rule shared by `hitTest` and the glide recognizer's closures:
    /// direct hit first (routing's own rule (a)), then zero-dead-zone gap resolution with
    /// the live bias/offset channels — so a glide origin resolves exactly like a tap would.
    private func routedKeyIndex(at point: CGPoint,
                                among buttons: [QwertyKeyButton],
                                outerEdgeSlop: CGFloat = 0) -> Int? {
        guard !buttons.isEmpty,
              isInsideResolvedHitRegion(point, outerEdgeSlop: outerEdgeSlop)
        else { return nil }
        return QwertyTouchRouting.keyIndex(at: point,
                                            keyFrames: buttons.map { $0.frame },
                                            in: bounds,
                                            bias: touchBias,
                                            offsets: touchOffsets)
    }

    /// Shared by both glide-origin and glide-update closures. Unlike tap hit-testing, glide
    /// samples are already in the view's bounds and do not need outer-edge forgiveness.
    func glideKeyIndex(at point: CGPoint) -> Int? {
        routedKeyIndex(at: point, among: rowButtons.flatMap { $0 })
    }

    private func isInsideResolvedHitRegion(_ point: CGPoint,
                                           outerEdgeSlop: CGFloat) -> Bool {
        // Slop is helpful at the physical outside edges, but the split thumb gap is an
        // intentional internal dead zone. Reject it before expanding any region.
        if layoutSplitGap?.contains(point) == true { return false }
        return layoutHitRegions.contains {
            $0.insetBy(dx: -outerEdgeSlop, dy: -outerEdgeSlop).contains(point)
        }
    }

    // MARK: - Per-key touch personalization (design §3)

    /// Captures every touch-down's location so the page host can read the tapped key's
    /// normalized offset from `lastTouchOffset(for:)` when the `.touchUpInside` tap lands.
    /// Only a touch delivered FOR this button may be attributed to it — a concurrent second
    /// thumb elsewhere must never leak in via `allTouches` (review follow-up), and a
    /// programmatic/a11y activation carries no touch at all. Both clear the capture instead.
    @objc private func captureTouchDown(_ button: QwertyKeyButton, event: UIEvent?) {
        guard let touch = event?.touches(for: button)?.first else {
            lastTouchDown = nil
            return
        }
        lastTouchDown = (button, touch.location(in: self))
        delegate?.qwertyKeyboardView(self, didTouchDown: button.key)
    }

    /// The last touch-down's offset from `key`'s frame CENTER, normalized by the frame's
    /// size (dx = (x − midX) / width, dy = (y − midY) / height) — the layout-independent
    /// form `QwertyTouchPersonalization` records. Nil when the last touch-down wasn't on
    /// this key (programmatic/a11y activation) or the frame is degenerate.
    func lastTouchOffset(for key: QwertyKey) -> (dx: Double, dy: Double)? {
        guard let last = lastTouchDown, last.button.key == key else { return nil }
        let frame = last.button.frame
        guard frame.width > 0, frame.height > 0 else { return nil }
        return (Double((last.location.x - frame.midX) / frame.width),
                Double((last.location.y - frame.midY) / frame.height))
    }

    /// Rebuilds the learned-offset maps from the host's model: `normalizedOffset(base)` is
    /// asked once per personalizable (single-letter) character key (nil = still warming up =
    /// no entry). The host calls this after every grid rebuild and personalization flush;
    /// frames may not be laid out yet at that point, so the view-space map is (re)derived on
    /// every layout pass too.
    func rebuildTouchOffsets(from normalizedOffset: (String) -> (dx: Double, dy: Double)?) {
        var normalized: [Int: (dx: Double, dy: Double)] = [:]
        for (index, button) in rowButtons.flatMap({ $0 }).enumerated() {
            guard case .character(let base, _) = button.key.kind,
                  QwertyTouchPersonalization.isPersonalizable(base),
                  let offset = normalizedOffset(base) else { continue }
            normalized[index] = offset
        }
        normalizedTouchOffsets = normalized
        denormalizeTouchOffsets()
    }

    private func clearTouchOffsets() {
        normalizedTouchOffsets = [:]
        touchOffsets = [:]
        // The buttons the capture points at are torn down with the grid — never let a
        // stale (removed) button be retained here or answer lastTouchOffset(for:).
        lastTouchDown = nil
    }

    /// Denormalizes the model's key-size-relative offsets into the view-space vectors
    /// `hitTest` feeds to routing, against the buttons' CURRENT frames.
    private func denormalizeTouchOffsets() {
        guard !normalizedTouchOffsets.isEmpty else {
            touchOffsets = [:]
            return
        }
        var result: [Int: CGVector] = [:]
        let buttons = rowButtons.flatMap { $0 }
        for (index, offset) in normalizedTouchOffsets {
            guard index < buttons.count else { continue }
            let frame = buttons[index].frame
            guard frame.width > 0, frame.height > 0 else { continue }
            result[index] = CGVector(dx: offset.dx * Double(frame.width),
                                     dy: offset.dy * Double(frame.height))
        }
        touchOffsets = result
    }

    /// Single-character key outputs keyed by the same flattened row/button index `hitTest` and
    /// `touchBias` use. The page host derives `touchBias` from this via
    /// `QwertyTouchRouting.bias(forCompletions:currentWord:keyOutputs:)`; keys whose current
    /// output isn't exactly one character (space, return, multi-character pack keys, …) are
    /// still included here — `bias(forCompletions:...)` itself ignores non-single-character
    /// outputs per its own contract, so no filtering is duplicated here.
    var characterKeyOutputs: [Int: String] {
        var outputs: [Int: String] = [:]
        for (index, button) in rowButtons.flatMap({ $0 }).enumerated() {
            if case .character = button.key.kind, let title = button.title(for: .normal) {
                outputs[index] = title
            }
        }
        return outputs
    }

    // MARK: - Glide capture (glide-and-accuracy design §4.1)

    /// Installs or removes the glide recognizer per the gate
    /// `FeatureFlags.isGlideTypingActive && !UIAccessibility.isVoiceOverRunning`.
    ///
    /// Re-evaluated at every grid (re)build (`configure`), on every settings sync (the page
    /// host forwards it, so a Beta-toggle flip lands live), and on VoiceOver status changes
    /// (the init-installed observer — a mid-session VoiceOver toggle tears down / reinstalls
    /// the recognizer immediately). Gate off ⇒ the recognizer OBJECT does not exist, so
    /// touch handling is byte-for-byte the pre-glide behavior (space-pan, backspace
    /// autorepeat, callouts, plain taps untouched).
    func updateGlideAvailability() {
        let active = FeatureFlags.isGlideTypingActive && !UIAccessibility.isVoiceOverRunning
        if active {
            guard glideRecognizer == nil else { return }
            let recognizer = QwertyGlideGestureRecognizer()
            // The recognizer is retained by this view (addGestureRecognizer) — its closures
            // must capture the view weakly or the pair leaks as a retain cycle.
            recognizer.isGlideOrigin = { [weak self] point in
                self?.isGlideOriginPoint(point) ?? false
            }
            recognizer.keyIndexAt = { [weak self] point in
                self?.glideKeyIndex(at: point)
            }
            recognizer.addTarget(self, action: #selector(handleGlide(_:)))
            addGestureRecognizer(recognizer)
            glideRecognizer = recognizer
        } else if let recognizer = glideRecognizer {
            removeGestureRecognizer(recognizer)
            glideRecognizer = nil
            removeGlideTrail(fading: false)
        }
    }

    /// A glide may only start on a single-letter `.character` key. The point resolves via
    /// the SAME zero-dead-zone routing `hitTest` uses, so a gap touch adjacent to a letter
    /// key is a valid origin (consistent with tap routing); the letter predicate is the
    /// shared `QwertyTouchPersonalization.isPersonalizable` — space, return, shift,
    /// backspace, digits, and multi-character strip keys all fail the origin check, which
    /// fail-fasts the recognizer and leaves their gestures untouched. The TOP STRIP (row 0,
    /// the leading flattened indices) is rejected wholesale: single-letter pack/custom strip
    /// keys are excluded from `letterKeyCenters()` below, so a glide starting on one would
    /// decode against geometry it isn't part of — strip touches stay plain taps.
    func isGlideOriginPoint(_ point: CGPoint) -> Bool {
        let buttons = rowButtons.flatMap { $0 }
        guard let index = glideKeyIndex(at: point),
              index >= (rowButtons.first?.count ?? 0),
              case .character(let base, _) = buttons[index].key.kind,
              QwertyTouchPersonalization.isPersonalizable(base) else { return false }
        return true
    }

    @objc private func handleGlide(_ recognizer: QwertyGlideGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            // .began is also the moment UIKit cancels the origin button's tracking
            // (cancelsTouchesInView) — the button's .touchCancel hides its callout via
            // keyTouchEnded, no manual bookkeeping here.
            updateGlideTrail(with: recognizer.points)
        case .ended:
            removeGlideTrail(fading: true)
            glideDelegate?.qwertyKeyboardView(self, didCompleteGlide: recognizer.points)
        case .cancelled:
            removeGlideTrail(fading: true)
        default:
            break
        }
    }

    /// Centers (view coordinates) of the currently rendered single-letter character keys,
    /// keyed by LOWERCASED base. Recomputed from the CURRENT buttons on every call — grid
    /// rebuilds (`configure`/`updateTopStrip`) and relayouts can never leave stale geometry.
    /// The page host feeds this to `QwertyGlideDecoder(keyCenters:lexicon:)`.
    ///
    /// The TOP STRIP (row 0) is skipped: strip pack/custom keys can be single letters too,
    /// and on the symbol layers they'd be the ONLY single-letter keys rendered — feeding the
    /// decoder a nonsense geometry of a few scattered strip centers instead of the letter
    /// grid. Only the layer rows below the strip are real glide geometry (and
    /// `isGlideOriginPoint` rejects strip origins to match).
    func letterKeyCenters() -> [String: CGPoint] {
        var centers: [String: CGPoint] = [:]
        for button in rowButtons.dropFirst().flatMap({ $0 }) {
            guard case .character(let base, _) = button.key.kind,
                  QwertyTouchPersonalization.isPersonalizable(base) else { continue }
            centers[base.lowercased()] = CGPoint(x: button.frame.midX, y: button.frame.midY)
        }
        return centers
    }

    private func updateGlideTrail(with points: [CGPoint]) {
        guard points.count > 1 else { return }
        let trail = glideTrailLayer ?? installGlideTrailLayer()
        let path = UIBezierPath()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        // Rebuild wholesale (a glide is at most a few hundred points — cheap) with implicit
        // path animation disabled so the line never smears between samples.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trail.path = path.cgPath
        CATransaction.commit()
    }

    private func installGlideTrailLayer() -> CAShapeLayer {
        let trail = CAShapeLayer()
        let palette = QwertyThemePalette.palette(for: KeyboardTheme.selectedOrAutomatic)
        trail.strokeColor = palette.text.withAlphaComponent(GlideTrail.strokeAlpha).cgColor
        trail.fillColor = nil
        trail.lineWidth = GlideTrail.lineWidth
        trail.lineCap = .round
        trail.lineJoin = .round
        trail.zPosition = GlideTrail.zPosition
        trail.frame = bounds
        layer.addSublayer(trail)
        glideTrailLayer = trail
        return trail
    }

    /// Removes the trail: a 0.25s opacity fade on normal ends, immediate removal when
    /// Reduce Motion is on or the recognizer is being torn down. The property nils out
    /// first so a new glide starting mid-fade always gets a fresh layer.
    private func removeGlideTrail(fading: Bool) {
        guard let trail = glideTrailLayer else { return }
        glideTrailLayer = nil
        guard fading, !UIAccessibility.isReduceMotionEnabled else {
            trail.removeFromSuperlayer()
            return
        }
        CATransaction.begin()
        CATransaction.setAnimationDuration(GlideTrail.fadeDuration)
        CATransaction.setCompletionBlock { trail.removeFromSuperlayer() }
        trail.opacity = 0
        CATransaction.commit()
    }

    // MARK: - Key callout

    @objc private func keyTouchDown(_ button: QwertyKeyButton) {
        // Native iPad keyboards show no key callouts — parity means none here either.
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        let palette = QwertyThemePalette.palette(for: KeyboardTheme.selectedOrAutomatic)
        calloutLabel.text = button.title(for: .normal)
        calloutLabel.backgroundColor = palette.plainFill
        calloutLabel.textColor = palette.text
        let keyFrame = button.frame
        let size = CGSize(width: max(keyFrame.width * 1.6, 44), height: keyFrame.height * 1.25)
        var frame = CGRect(x: keyFrame.midX - size.width / 2,
                           y: keyFrame.minY - size.height - 4,
                           width: size.width,
                           height: size.height)
        frame.origin.y = max(frame.origin.y, 0)
        frame.origin.x = min(max(frame.origin.x, 2), bounds.width - size.width - 2)
        calloutLabel.frame = frame
        calloutLabel.isHidden = false
        bringSubviewToFront(calloutLabel)
    }

    @objc private func keyTouchEnded(_ button: QwertyKeyButton) {
        calloutLabel.isHidden = true
    }

    func showAlternates(_ values: [String], from button: QwertyKeyButton) {
        dismissAlternates()
        calloutLabel.isHidden = true
        guard !values.isEmpty else { return }

        let layout = QwertyAlternateCalloutLayout.resolve(
            valueCount: values.count,
            availableWidth: bounds.width
        )
        guard layout.itemWidth > 0 else { return }
        let callout = QwertyAlternateCalloutView(
            values: values,
            itemWidth: layout.itemWidth
        )
        let size = CGSize(width: layout.totalWidth, height: 52)
        var origin = CGPoint(x: button.frame.midX - size.width / 2,
                             y: button.frame.minY - size.height - 6)
        origin.x = min(max(origin.x, 2), max(bounds.width - size.width - 2, 2))
        origin.y = max(origin.y, 2)
        callout.frame = CGRect(origin: origin, size: size)
        addSubview(callout)
        bringSubviewToFront(callout)
        alternateCallout = callout
        _ = updateAlternateHighlight(at: CGPoint(x: button.frame.midX, y: button.frame.midY))
    }

    @discardableResult
    func updateAlternateHighlight(at point: CGPoint) -> String? {
        guard let callout = alternateCallout else { return nil }
        return callout.updateHighlight(horizontalLocation: point.x - callout.frame.minX)
    }

    func releaseAlternate() -> String? {
        guard let callout = alternateCallout else { return nil }
        let value = callout.releaseSelection()
        dismissAlternates()
        return value
    }

    func dismissAlternates() {
        alternateCallout?.removeFromSuperview()
        alternateCallout = nil
        calloutLabel.isHidden = true
    }

    /// Relabels cased keys and the shift key for the current shift state without rebuilding.
    func update(shiftState: QwertyShiftMachine.State) {
        for button in rowButtons.flatMap({ $0 }) {
            switch button.key.kind {
            case .character(let base, let shifted):
                if shifted != base {
                    button.setLabel(shiftState == .lowercase ? base : shifted)
                }
                button.setAlternateAccessibilityValues(
                    QwertyAlternates.values(for: base,
                                            uppercase: shiftState != .lowercase)
                )
            case .shift:
                switch shiftState {
                case .lowercase:
                    button.setGlyph("shift")
                    button.showsEngaged = false
                case .shifted:
                    button.setGlyph("shift.fill")
                    button.showsEngaged = true
                case .capsLock:
                    button.setGlyph("capslock.fill")
                    button.showsEngaged = true
                }
            default:
                break
            }
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !rowLayouts.isEmpty else { return }

        let traits = layoutTraits
        let idiom = traits.userInterfaceIdiom
        let floating = KeyboardHeightPreset.isFloatingKeyboard(
            isPad: idiom == .pad,
            width: bounds.width,
            containerHeight: window?.bounds.height ?? UIScreen.main.bounds.height
        )
        let mode = QwertyLayoutGeometry.resolvedMode(
            preference: UserPrefs.qwertyLayoutMode,
            bounds: bounds,
            idiom: idiom,
            horizontalSizeClass: traits.horizontalSizeClass,
            isFloating: floating
        )
        let layout = QwertyLayoutGeometry.layout(
            bounds: bounds,
            rows: rowLayouts,
            mode: mode,
            idiom: idiom,
            keyGap: Metrics.keyGap,
            rowGap: Metrics.rowGap,
            edgeInset: Metrics.edgeInset,
            topInset: Metrics.topInset,
            bottomInset: Metrics.bottomInset
        )
        layoutContentFrame = layout.contentFrame
        layoutHitRegions = layout.hitRegions
        layoutSplitGap = layout.splitGap
        for (rowIndex, row) in layout.rows.enumerated() {
            for (keyIndex, frame) in row.frames.enumerated()
                where rowIndex < rowButtons.count && keyIndex < rowButtons[rowIndex].count {
                rowButtons[rowIndex][keyIndex].frame = frame
            }
        }
        // Key frames just changed — re-derive the view-space offset vectors from the
        // layout-independent normalized map.
        denormalizeTouchOffsets()
        if mode != resolvedLayoutMode {
            resolvedLayoutMode = mode
            delegate?.qwertyKeyboardView(self, didResolveLayoutMode: mode)
        }
    }

    // MARK: - Private

    @objc private func keyTapped(_ button: QwertyKeyButton) {
        delegate?.qwertyKeyboardView(self, didTap: button.key)
    }

    private func decorate(_ button: QwertyKeyButton, for key: QwertyKey) {
        switch key.kind {
        case .character(let base, _):
            button.setLabel(base)
        case .shift:
            button.setGlyph("shift")
            button.accessibilityLabel = NSLocalizedString("Shift", comment: "shift key")
        case .backspace:
            button.setGlyph("delete.left")
            button.accessibilityLabel = NSLocalizedString("Delete", comment: "backspace key")
        case .space:
            button.setLabel(NSLocalizedString("space", comment: "space bar label"), pointSize: 16)
        case .ret:
            button.setLabel(returnKeyLabel, pointSize: 16)
        case .globe:
            button.setGlyph("globe")
            button.accessibilityLabel = NSLocalizedString("Next keyboard", comment: "globe key")
        case .layerSwitch(let layer):
            switch layer {
            case .letters: button.setLabel("ABC", pointSize: 16)
            case .symbols: button.setLabel("123", pointSize: 16)
            case .extendedSymbols: button.setLabel("#+=", pointSize: 16)
            }
        case .numpadFlip:
            // Deliberately distinct from both the globe and the "123" layer key — this flips
            // the whole canvas to the full NumPad (plan §2's differentiator).
            button.setGlyph("circle.grid.3x3")
            button.accessibilityLabel = NSLocalizedString("NumPad", comment: "numpad flip key")
        case .packSwitch:
            // The same pack-switch identity the numpad keyboard uses — never a second globe.
            button.setGlyph(KeyGlyph.packSwitch, pointSize: 15)
            button.accessibilityLabel = NSLocalizedString("Switch pack", comment: "pack switch key")
        case .dateTimeToken(let label, _):
            button.setLabel(label, pointSize: 14)
        case .snippet(let label, _):
            button.setLabel(label, pointSize: 13)
            button.accessibilityHint = NSLocalizedString("Inserts the snippet", comment: "snippet strip key hint")
        case .dismissKeyboard:
            button.setGlyph("keyboard.chevron.compact.down")
            button.accessibilityLabel = NSLocalizedString("Hide keyboard", comment: "dismiss keyboard key")
        }
    }
}
