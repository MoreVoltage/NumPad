//
//  CalculateIntent.swift
//  NumPad
//
//  App Intents support (App target only — the Keyboard extension is untouched).
//

import AppIntents

/// Siri / Shortcuts / Spotlight entry point for NumPad's inline calculator. Reuses
/// `Calculator.evaluate`/`Calculator.format` exactly — the same engine that backs the keyboard's
/// "=" key — and feeds the result into `ResultTape` so the tape is a cross-surface workspace.
///
/// Localization note: every `LocalizedStringResource` on this declarative surface (title,
/// description, `@Parameter` title) MUST be a literal — see the note atop `TipIntent.swift` for why
/// (`appintentsmetadataprocessor` statically parses this file at build time and can't evaluate a
/// call like `NSLocalizedString(...)`).
struct CalculateIntent: AppIntent {
    static var title: LocalizedStringResource {
        LocalizedStringResource("Calculate", comment: "App Intent: Calculate title shown in Shortcuts and Siri")
    }

    static var description: IntentDescription {
        IntentDescription(LocalizedStringResource("Evaluate a math expression using NumPad's calculator — the same engine as the keyboard's = key.", comment: "App Intent: Calculate description shown in the Shortcuts app"))
    }

    @Parameter(title: LocalizedStringResource("Expression", comment: "App Intent: Calculate 'expression' parameter title"))
    var expression: String

    static var parameterSummary: some ParameterSummary {
        Summary("Calculate \(\.$expression)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        guard FeatureFlags.isAppIntentsActive else {
            throw NumPadIntentError.disabled
        }
        guard let result = Calculator.evaluate(expression) else {
            throw NumPadIntentError.invalidExpression(expression)
        }
        // Feed the shared tape so a result computed via Siri can be reused from the keyboard's
        // long-press-return tape, and vice versa.
        ResultTape.shared.add(Calculator.format(result))
        let dialog = AppIntentFormatting.calculateDialog(expression: expression, result: result)
        return .result(value: result, dialog: IntentDialog(stringLiteral: dialog))
    }
}
