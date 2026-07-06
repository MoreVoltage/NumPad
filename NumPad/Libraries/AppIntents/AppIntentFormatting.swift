//
//  AppIntentFormatting.swift
//  NumPad
//
//  App Intents support (App target only — the Keyboard extension is untouched).
//
//  Pure, unit-tested string formatting for App Intent dialogs. No math lives here — every number
//  passed in is already the output of Calculator/UnitConverter/TaxTipMath.
//

import Foundation

enum AppIntentFormatting {
    /// Trims a Double to NumPad's calculator display format (e.g. "20.5", not "20.500000"),
    /// reusing `Calculator.format` exactly so numbers read the same across every surface.
    static func number(_ value: Double) -> String {
        Calculator.format(value)
    }

    /// "3 cups is 709.76 ml" — `ConvertUnitsIntent`'s spoken result.
    static func conversionDialog(value: Double, fromLabel: String, result: Double, toLabel: String) -> String {
        let format = NSLocalizedString("%@ %@ is %@ %@", comment: "App Intent conversion result dialog, e.g. '3 cups is 709.76 ml'. %1$@ input value, %2$@ input unit, %3$@ result value, %4$@ result unit")
        return String(format: format, number(value), fromLabel, number(result), toLabel)
    }

    /// "2+2*3 is 8" — `CalculateIntent`'s spoken result.
    static func calculateDialog(expression: String, result: Double) -> String {
        let format = NSLocalizedString("%@ is %@", comment: "App Intent calculate result dialog, e.g. '2+2 is 4'. %1$@ the expression, %2$@ the result")
        return String(format: format, expression, number(result))
    }

    /// "Tip: 9. Total: 59." — `TipIntent`'s spoken result.
    static func tipDialog(tip: Double, total: Double) -> String {
        let format = NSLocalizedString("Tip: %@. Total: %@.", comment: "App Intent tip result dialog. %1$@ tip amount, %2$@ total amount")
        return String(format: format, number(tip), number(total))
    }
}
