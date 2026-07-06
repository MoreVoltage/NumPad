//
//  NumPadIntentError.swift
//  NumPad
//
//  App Intents support (App target only — the Keyboard extension is untouched).
//

import AppIntents

/// Errors thrown by NumPad's App Intents. Conforming to `CustomLocalizedStringResourceConvertible`
/// lets Siri/Shortcuts speak/display `localizedStringResource` directly instead of a generic
/// "Something went wrong."
enum NumPadIntentError: Error, CustomLocalizedStringResourceConvertible {
    /// `ConvertUnitsIntent`: the two units belong to different `UnitConverter.Category` values.
    case incompatibleUnits(from: String, to: String)
    /// `CalculateIntent`: `Calculator.evaluate` returned `nil` (malformed or non-finite result).
    case invalidExpression(String)
    /// Any intent: a numeric parameter failed basic input validation (e.g. zero/negative/NaN).
    case invalidAmount
    /// The App Intents kill switch (`FeatureFlags.isAppIntentsActive`) is off.
    case disabled

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .incompatibleUnits(let from, let to):
            let format = NSLocalizedString("NumPad can't convert %@ to %@ — they're different kinds of units.", comment: "App Intent error: incompatible unit categories, e.g. cm to kg. %1$@ is the from-unit label, %2$@ is the to-unit label")
            return LocalizedStringResource(stringLiteral: String(format: format, from, to))
        case .invalidExpression(let expression):
            let format = NSLocalizedString("NumPad couldn't calculate \"%@\".", comment: "App Intent error: the Calculate intent's expression didn't parse. %@ is the expression the user gave")
            return LocalizedStringResource(stringLiteral: String(format: format, expression))
        case .invalidAmount:
            return LocalizedStringResource(stringLiteral: NSLocalizedString("Enter a value greater than zero.", comment: "App Intent error: a numeric parameter was zero, negative, or not a number"))
        case .disabled:
            return LocalizedStringResource(stringLiteral: NSLocalizedString("Siri and Shortcuts support is temporarily unavailable. Please try again later.", comment: "App Intent error: the App Intents feature is disabled by its kill switch"))
        }
    }
}
