//
//  QwertyGlideGestureRecognizer.swift
//  Keyboard
//
//  Fail-fast glide capture for the QWERTY page (glide-and-accuracy design §4.1).
//  Implemented by the glide-capture pass.
//

import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Captures a glide (draw-through-letters) touch on `QwertyKeyboardView`.
///
/// A direct `UIGestureRecognizer` subclass, deliberately NOT `UIPanGestureRecognizer`:
/// pan recognizes on any small translation, but glide needs FAIL-FAST semantics — a touch
/// that doesn't begin on a letter key must fail immediately in `touchesBegan` so the space
/// bar's cursor pan, backspace autorepeat, shift, and strip keys behave exactly as if this
/// recognizer didn't exist. A letter-origin touch stays `.possible` (the button underneath
/// tracks normally, callout included) until the pure `QwertyGlideCapture` thresholds pass;
/// the upgrade to `.began` is what makes UIKit cancel the origin button's tracking
/// (`cancelsTouchesInView` stays default `true` — no manual `touchesCancelled` synthesis),
/// which is the whole tap-vs-glide disambiguation mechanism. A touch that ends while still
/// `.possible` fails — it was a tap, and the button handles it normally.
///
/// The recognizer owns no geometry: the hosting view injects `isGlideOrigin` (does this
/// point resolve to a single-letter key, via the view's own zero-dead-zone routing) and
/// `keyIndexAt` (key resolution over the CURRENT key frames, feeding the distinct-key
/// threshold). Both closures must capture the view weakly — the view retains this
/// recognizer via `addGestureRecognizer`.
final class QwertyGlideGestureRecognizer: UIGestureRecognizer {

    /// Whether a touch-down location can start a glide (the view answers: the point
    /// resolves to a `.character` key whose base is a single letter). Unset → every touch
    /// fails, keeping an unconfigured recognizer inert.
    var isGlideOrigin: ((CGPoint) -> Bool)?

    /// Resolves a sampled location to a key index over the view's current key frames
    /// (`nil` = no key), feeding `QwertyGlideCapture`'s distinct-key threshold.
    var keyIndexAt: ((CGPoint) -> Int?)?

    /// Every sampled location of the tracked touch, in the view's coordinate space and in
    /// order — the trail redraws from this on `.changed`, and the host reads it as the
    /// completed glide path on `.ended`. Computed straight off the capture state (single
    /// source of truth — no per-sample copy to keep in sync); `reset()` clears it by
    /// resetting `captureState` after the gesture resolves.
    var points: [CGPoint] { captureState.points }

    private var captureState = QwertyGlideCapture.State()

    /// The single touch this gesture tracks — glide is strictly one-finger, so any touch
    /// arriving while one is tracked is ignored outright and can never join or disturb
    /// the capture.
    private var trackedTouch: UITouch?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard trackedTouch == nil, let touch = touches.first else {
            for touch in touches where touch !== trackedTouch {
                ignore(touch, for: event)
            }
            return
        }
        // Multi-touch landing in one event: track one finger, ignore the rest.
        for extra in touches where extra !== touch {
            ignore(extra, for: event)
        }
        let location = touch.location(in: view)
        guard isGlideOrigin?(location) == true else {
            // Fail-fast: non-letter origins (space, backspace, shift, strip keys, gaps
            // routed to any of them) opt out immediately and UIKit stops delivering this
            // touch sequence to the recognizer.
            state = .failed
            return
        }
        trackedTouch = touch
        recordSample(at: location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let tracked = trackedTouch, touches.contains(tracked) else { return }
        recordSample(at: tracked.location(in: view))
        switch state {
        case .possible:
            if QwertyGlideCapture.shouldUpgrade(state: captureState) {
                state = .began
            }
        case .began, .changed:
            state = .changed
        default:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard let tracked = trackedTouch, touches.contains(tracked) else { return }
        if state == .began || state == .changed {
            // Capture the lift point, then hand the completed path to the host's action.
            recordSample(at: tracked.location(in: view))
            state = .ended
        } else {
            // Never upgraded: it was a tap. Failing (not cancelling) lets the origin
            // button's own .touchUpInside fire untouched.
            state = .failed
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        guard let tracked = trackedTouch, touches.contains(tracked) else { return }
        state = (state == .began || state == .changed) ? .cancelled : .failed
    }

    override func reset() {
        super.reset()
        trackedTouch = nil
        captureState = QwertyGlideCapture.State()
    }

    // MARK: - Private

    /// Records only locations that resolve inside the host's current layout hit regions.
    /// Kept internal so the gap/no-sample contract can be verified without synthesizing UITouch.
    func recordSample(at location: CGPoint) {
        guard let keyIndex = keyIndexAt?(location) else { return }
        captureState.record(point: location, keyIndex: keyIndex)
    }
}
