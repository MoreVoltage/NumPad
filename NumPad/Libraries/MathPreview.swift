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
