//
//  MathPreview.swift
//  NumPad / Keyboard
//
//  Shared (both targets). Pure decision + formatting logic for the Live Math Preview feature (the
//  floating "= result" chip shown while typing an expression), plus the Remote Config kill-switch
//  mirror the keyboard extension reads directly (it has no Firebase Remote Config of its own — see
//  RemoteConfigManager.mirrorLiveMathPreviewKillSwitch). Kept pure/UIKit-free so it's fully
//  unit-testable, mirroring the Calculator/UnitConverter/TaxTipMath pattern.
//

import Foundation

// MARK: - Kill switch

/// Combines the user-facing `UserPrefs.liveMathPreview` toggle with the Remote Config kill switch
/// mirrored into the shared app group. Mirrors the shape of `FeatureFlags.dragReorderActive`, but
/// unlike that one-app-side-consumer case, `remoteEnabled` here must be *stored*, not fetched live,
/// because the keyboard extension has no Remote Config access at all.
enum LiveMathPreview {
    /// Mirrored copy of the `live_math_preview_enabled` Remote Config value, written by the app
    /// (see `RemoteConfigManager.mirrorLiveMathPreviewKillSwitch`) on every fetch. Defaults true so
    /// behavior is unchanged for everyone until the app has fetched at least once — and forever
    /// after, until explicitly flipped off in the Firebase console.
    @UserDefault(key: Constants.mathPreviewRemoteEnabled.rawValue, defaultValue: true, userDefaults: .group)
    static var remoteEnabled: Bool

    /// Pure combinator: both the remote kill switch and the local toggle must be on. Self-contained
    /// (all state passed in) so it's unit-testable without touching UserDefaults.
    static func isActive(remoteEnabled: Bool, localEnabled: Bool) -> Bool {
        return remoteEnabled && localEnabled
    }

    /// Convenience reading the live stored values — what call sites actually use.
    static var isEnabled: Bool {
        isActive(remoteEnabled: remoteEnabled, localEnabled: UserPrefs.liveMathPreview)
    }
}

// MARK: - Result chip decision + formatting

/// Pure decision logic for the Live Math Preview chip: given the text immediately before the
/// cursor, should a chip show, and what should it say? Mirrors `KeyboardViewController
/// .evaluateInlineExpression()`'s trailing-expression parsing (same character set, same
/// `Calculator.evaluate` call) so the chip and the "=" key always agree on what counts as a valid
/// expression, and so tapping the chip inserts exactly what "=" would have inserted.
enum MathPreviewChip {
    /// A decision to show the chip. `expression` is the exact raw trailing text that was matched
    /// (how many characters to delete on insert — including any surrounding whitespace, matching
    /// `evaluateInlineExpression`'s own `raw` semantics). `insertText` is what tapping the chip
    /// inserts (identical semantics to the "=" key). `displayText` is what the capsule shows —
    /// grouped for readability, but otherwise the same number.
    struct Decision: Equatable {
        let expression: String
        let insertText: String
        let displayText: String
    }

    /// Cheap pre-check, meant to run on every keystroke before any parsing/timer work: the chip can
    /// only ever apply when the character immediately before the cursor could plausibly end a
    /// numeric expression. This keeps the common case (typing prose, or having just inserted a
    /// result) allocation-free — callers should hide the chip immediately (no debounce) when this
    /// returns false, and only schedule the real evaluation when it returns true.
    static func lastCharacterCouldEndExpression(_ text: String) -> Bool {
        guard let last = text.last else { return false }
        return last.isNumber || "+-*/%()×÷−".contains(last)
    }

    /// Decide whether to show the chip for the text immediately before the cursor, and what it
    /// should say. Returns nil when the chip should be hidden: no trailing expression, fewer than
    /// two operands (a bare number like "42" has nothing to compute), or an invalid parse.
    /// `decimalSeparator` matches `Calculator.evaluate`'s locale handling.
    static func decide(textBeforeCursor: String, decimalSeparator: String = ".") -> Decision? {
        guard lastCharacterCouldEndExpression(textBeforeCursor) else { return nil }
        let exprChars = Set("0123456789+-*/%()×÷− .,\(decimalSeparator)")
        let raw = String(textBeforeCursor.reversed().prefix { exprChars.contains($0) }.reversed())
        let expression = raw.trimmingCharacters(in: .whitespaces)
        guard !expression.isEmpty, operandCount(in: expression) >= 2 else { return nil }
        guard let result = Calculator.evaluate(expression, decimalSeparator: decimalSeparator) else { return nil }
        let insertText = Calculator.format(result, decimalSeparator: decimalSeparator)
        return Decision(expression: raw, insertText: insertText,
                         displayText: displayText(for: result, decimalSeparator: decimalSeparator))
    }

    /// A cheap operand-count heuristic: split on operator/paren characters and count the non-empty
    /// remainders. A bare number ("42") yields one chunk; anything actually combining two numbers
    /// ("250-20%", "-5+3", "3*-2") yields two or more. `Calculator.evaluate` still does the real
    /// parse/validation — this only exists to avoid showing a chip that just restates the number
    /// the user already typed.
    private static func operandCount(in expression: String) -> Int {
        let splitters = CharacterSet(charactersIn: "+-*/%×÷−()")
        return expression.components(separatedBy: splitters)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .count
    }

    /// Reused across every recompute so the typing hot path never allocates a `NumberFormatter` —
    /// measurable in a ~50MB keyboard extension. Display-only: adds a thousands separator so large
    /// results stay readable in the small capsule. What actually gets inserted on tap is always
    /// `Calculator.format`'s ungrouped output (`insertText` above), matching the "=" key exactly.
    private static let displayFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 10
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    static func displayText(for result: Double, decimalSeparator: String = ".") -> String {
        displayFormatter.decimalSeparator = decimalSeparator
        displayFormatter.groupingSeparator = decimalSeparator == "," ? "." : ","
        guard result.isFinite, let text = displayFormatter.string(from: NSNumber(value: result)) else {
            return Calculator.format(result, decimalSeparator: decimalSeparator)
        }
        return text
    }
}

// MARK: - Refresh trigger (when to recompute the chip)

/// Owns *when* the chip is recomputed: a cheap synchronous guard, then a short debounce before the
/// real `MathPreviewChip.decide`. UIKit-free (the scheduler and proxy reads are injected) so the
/// keystroke → chip path is unit-testable.
///
/// Two entry points, both required: `UITextInputDelegate.textDidChange`/`selectionDidChange` are
/// NOT guaranteed to fire after the keyboard extension's *own* `textDocumentProxy` edits (they
/// report host-side document changes), so relying on them alone left the chip waiting for an
/// unrelated extra tap. The keyboard calls `keyboardDidEditText()` after each of its own edits.
final class MathPreviewRefreshTrigger {
    /// Schedules `work` after `delay`; returns a cancel closure.
    typealias Schedule = (_ delay: TimeInterval, _ work: @escaping () -> Void) -> () -> Void

    private let debounce: TimeInterval
    private let contextBeforeInput: () -> String?
    private let isEligible: () -> Bool
    private let decimalSeparator: () -> String
    private let schedule: Schedule
    private let show: (MathPreviewChip.Decision) -> Void
    private let hide: () -> Void
    private var cancelPending: (() -> Void)?
    /// What the chip currently displays (nil = hidden). Display-only: it is never applied as-is —
    /// `decisionForActivation` re-derives the decision from the live document at tap time.
    private(set) var displayedDecision: MathPreviewChip.Decision?

    init(debounce: TimeInterval,
         contextBeforeInput: @escaping () -> String?,
         isEligible: @escaping () -> Bool,
         decimalSeparator: @escaping () -> String,
         schedule: @escaping Schedule,
         show: @escaping (MathPreviewChip.Decision) -> Void,
         hide: @escaping () -> Void) {
        self.debounce = debounce
        self.contextBeforeInput = contextBeforeInput
        self.isEligible = isEligible
        self.decimalSeparator = decimalSeparator
        self.schedule = schedule
        self.show = show
        self.hide = hide
    }

    /// Call right after the keyboard's own `insertText`/`deleteBackward`/caret move.
    func keyboardDidEditText() { handleChange(isOwnEdit: true) }

    /// Call from `textDidChange`/`selectionDidChange` (host-side edits, cursor taps, field switches).
    func hostTextDidChange() { handleChange(isOwnEdit: false) }

    /// Drop any pending debounced evaluation (e.g. the chip is being hidden for another reason).
    func cancel() {
        cancelPendingRefresh()
        displayedDecision = nil
    }

    private func cancelPendingRefresh() {
        cancelPending?()
        cancelPending = nil
    }

    /// The user tapped the chip: the decision to apply (delete `expression`, insert `insertText`),
    /// or nil to do nothing. The shown result may be stale (an edit inside the debounce window, or a
    /// host undo/caret move that reported nothing), and applying a stale `expression.count` would
    /// delete unrelated text. So the decision is re-derived from the live context and applied only
    /// if it is exactly what the chip shows and nothing is selected (`deleteBackward` would remove
    /// the selection first). Otherwise the chip is refreshed to the live state and nothing applies.
    func decisionForActivation(selectedText: String?) -> MathPreviewChip.Decision? {
        cancelPendingRefresh()
        let hasSelection = !(selectedText ?? "").isEmpty
        let live = hasSelection || !isEligible() ? nil : liveDecision()
        guard let shown = displayedDecision, let live, live == shown else {
            present(live)
            return nil
        }
        return shown
    }

    /// Unusable context hides immediately (no debounce) so the chip never lingers once the trailing
    /// text can't possibly be an expression. A host callback stops there (prose typing allocates no
    /// timer) without cancelling a pending read. An own edit always gets one coalesced delayed
    /// read, because the proxy can lag behind our own insert (nil, or the previous text) and the
    /// fire-time read is the only chance to catch up without another event.
    private func handleChange(isOwnEdit: Bool) {
        guard isEligible() else {
            cancelPendingRefresh()
            conceal()
            return
        }
        let plausible = contextBeforeInput().map(MathPreviewChip.lastCharacterCouldEndExpression) ?? false
        if !plausible { conceal() }
        guard plausible || isOwnEdit else { return }
        cancelPendingRefresh()
        cancelPending = schedule(debounce) { [weak self] in
            self?.cancelPending = nil
            self?.evaluate()
        }
    }

    /// Guards re-checked: state (an overlay opening, the floating-keyboard state) can change during
    /// the debounce window. Context is read here, at fire time, not at schedule time.
    private func evaluate() {
        present(isEligible() ? liveDecision() : nil)
    }

    private func liveDecision() -> MathPreviewChip.Decision? {
        guard let before = contextBeforeInput() else { return nil }
        return MathPreviewChip.decide(textBeforeCursor: before, decimalSeparator: decimalSeparator())
    }

    private func present(_ decision: MathPreviewChip.Decision?) {
        guard let decision else { return conceal() }
        displayedDecision = decision
        show(decision)
    }

    private func conceal() {
        displayedDecision = nil
        hide()
    }
}

// MARK: - Chip visibility (fade in / fade out)

/// The chip's show/hide state machine, UIKit-free (the view's `isHidden` setter and the alpha fade
/// are injected) so fade timing races are unit-testable. `fade` animates alpha to the given value
/// and calls `completion` when done (synchronously under Reduce Motion).
final class MathPreviewChipVisibility {
    typealias Fade = (_ alpha: Double, _ completion: @escaping () -> Void) -> Void

    private let setHidden: (Bool) -> Void
    private let fade: Fade
    /// Mirrors the view's `isHidden`.
    private(set) var isHidden = true
    /// A fade-out is in flight; the view is still visible until its completion runs.
    private var isFadingOut = false
    /// Bumped by every show/hide so a superseded fade-out's completion can tell it is stale.
    private var generation = 0

    init(setHidden: @escaping (Bool) -> Void, fade: @escaping Fade) {
        self.setHidden = setHidden
        self.fade = fade
    }

    /// Supersedes an in-flight fade-out (its completion becomes a no-op) — otherwise a result
    /// arriving within the 150 ms fade would be hidden by the old completion.
    func show() {
        guard isHidden || isFadingOut else { return } // already visible — no re-animate
        isFadingOut = false
        generation += 1
        isHidden = false
        setHidden(false)
        fade(1) {}
    }

    func hide() {
        guard !isHidden, !isFadingOut else { return }
        isFadingOut = true
        generation += 1
        let token = generation
        fade(0) { [weak self] in
            guard let self, self.generation == token else { return }
            self.isFadingOut = false
            self.isHidden = true
            self.setHidden(true)
        }
    }
}

#if DEBUG
/// DEBUG/UI-test only. Lets a UI test drop the host `textDidChange`/`selectionDidChange` callbacks
/// for the chip, proving the keyboard's own-edit notification alone makes the chip appear
/// (set via the `-debugRoute mathpreview?hostcallbacks=0` launch route).
enum MathPreviewTestHooks {
    @UserDefault(key: Constants.debugMathPreviewIgnoresHostCallbacks.rawValue, defaultValue: false, userDefaults: .group)
    static var ignoresHostTextCallbacks: Bool
}
#endif
