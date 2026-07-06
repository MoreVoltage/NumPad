//
//  ConvertUnitsIntent.swift
//  NumPad
//
//  App Intents support (App target only — the Keyboard extension is untouched).
//

import AppIntents

/// Siri / Shortcuts / Spotlight entry point for NumPad's offline unit converter. Reuses
/// `UnitConverter.convert` exactly — no new conversion math lives here. Fully functional
/// regardless of pack ownership (see `NumPadShortcuts` doc comment for the monetization
/// reasoning): a locked keyboard key is the product; a free Siri conversion is marketing.
///
/// Localization note: every `LocalizedStringResource` on this declarative surface (title,
/// description, `@Parameter` titles) MUST be a literal — see the note atop `TipIntent.swift` for why
/// (`appintentsmetadataprocessor` statically parses this file at build time and can't evaluate a
/// call like `NSLocalizedString(...)`).
struct ConvertUnitsIntent: AppIntent {
    static var title: LocalizedStringResource {
        LocalizedStringResource("Convert Units", comment: "App Intent: Convert Units title shown in Shortcuts and Siri")
    }

    static var description: IntentDescription {
        IntentDescription(LocalizedStringResource("Convert a value between units using NumPad's offline converter — the same math as the Units & Cooking keyboard packs.", comment: "App Intent: Convert Units description shown in the Shortcuts app"))
    }

    @Parameter(title: LocalizedStringResource("Value", comment: "App Intent: Convert Units 'value' parameter title"))
    var value: Double

    @Parameter(title: LocalizedStringResource("From", comment: "App Intent: Convert Units 'from unit' parameter title"))
    var fromUnit: ConversionUnit

    @Parameter(title: LocalizedStringResource("To", comment: "App Intent: Convert Units 'to unit' parameter title"))
    var toUnit: ConversionUnit

    static var parameterSummary: some ParameterSummary {
        Summary("Convert \(\.$value) \(\.$fromUnit) to \(\.$toUnit)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        guard FeatureFlags.isAppIntentsActive else {
            throw NumPadIntentError.disabled
        }
        guard value.isFinite else {
            throw NumPadIntentError.invalidAmount
        }
        guard let converted = UnitConverter.convert(value, from: fromUnit.rawValue, to: toUnit.rawValue) else {
            throw NumPadIntentError.incompatibleUnits(from: fromUnit.spokenLabel, to: toUnit.spokenLabel)
        }
        let dialog = AppIntentFormatting.conversionDialog(value: value, fromLabel: fromUnit.spokenLabel, result: converted, toLabel: toUnit.spokenLabel)
        return .result(value: converted, dialog: IntentDialog(stringLiteral: dialog))
    }
}
