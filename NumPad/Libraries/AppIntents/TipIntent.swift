//
//  TipIntent.swift
//  NumPad
//
//  App Intents support (App target only — the Keyboard extension is untouched).
//

import AppIntents

/// Siri / Shortcuts / Spotlight entry point for NumPad's tax/tip math. Reuses `TaxTipMath.total`/
/// `TaxTipMath.tipOnly` exactly; the only new logic anywhere in this feature is
/// `TaxTipMath.preTaxAmount`, added alongside this intent so a tax-inclusive bill amount can be
/// normalized to the pre-tax subtotal those two functions expect.
///
/// Parameter design note: the task brief asked for "bill amount + tip percent (+ optional
/// tax-inclusive flag matching TaxTipMath semantics)". A tax-inclusive flag is meaningless without
/// a tax rate to back out, so this intent also exposes an optional `taxPercent` (default 0) —
/// without it the flag would have nothing to do. With `taxPercent` at its default of 0, the
/// tax-inclusive flag is a no-op and the intent behaves exactly like a plain bill+tip calculator.
///
/// Localization note: every `LocalizedStringResource` on this declarative surface (title,
/// description, `@Parameter`/`@Property` titles, display representations) MUST be a literal —
/// `appintentsmetadataprocessor` statically parses this file at build time to export Siri/Spotlight
/// metadata and cannot evaluate a call like `NSLocalizedString(...)`. `LocalizedStringResource`'s
/// own `init(_:comment:)` still gets picked up by Xcode's normal string-extraction tooling (via a
/// generated strings table), so nothing is lost versus routing through `NSLocalizedString`. Runtime
/// dialog strings (`AppIntentFormatting`, `NumPadIntentError`) are NOT on this static surface and
/// keep using `NSLocalizedString` like the rest of the app.
struct TipIntent: AppIntent {
    static var title: LocalizedStringResource {
        LocalizedStringResource("Calculate Tip", comment: "App Intent: Calculate Tip title shown in Shortcuts and Siri")
    }

    static var description: IntentDescription {
        IntentDescription(LocalizedStringResource("Calculate a tip and total using NumPad's tax/tip math — tip is always computed on the pre-tax subtotal, the standard receipt convention.", comment: "App Intent: Calculate Tip description shown in the Shortcuts app"))
    }

    @Parameter(title: LocalizedStringResource("Bill Amount", comment: "App Intent: Calculate Tip 'bill amount' parameter title"))
    var billAmount: Double

    @Parameter(title: LocalizedStringResource("Tip Percent", comment: "App Intent: Calculate Tip 'tip percent' parameter title"))
    var tipPercent: Double

    @Parameter(title: LocalizedStringResource("Tax Percent", comment: "App Intent: Calculate Tip optional 'tax percent' parameter title"), default: 0)
    var taxPercent: Double

    @Parameter(title: LocalizedStringResource("Bill Already Includes Tax", comment: "App Intent: Calculate Tip optional 'tax-inclusive' parameter title"), default: false)
    var taxInclusive: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Calculate a \(\.$tipPercent)% tip on \(\.$billAmount)") {
            \.$taxPercent
            \.$taxInclusive
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<TipCalculationResult> & ProvidesDialog {
        guard FeatureFlags.isAppIntentsActive else {
            throw NumPadIntentError.disabled
        }
        guard billAmount > 0, tipPercent >= 0, taxPercent >= 0,
              billAmount.isFinite, tipPercent.isFinite, taxPercent.isFinite else {
            throw NumPadIntentError.invalidAmount
        }
        let taxRate = taxPercent / 100
        let tipRate = tipPercent / 100
        let preTaxAmount = taxInclusive
            ? TaxTipMath.preTaxAmount(fromTaxInclusiveTotal: billAmount, taxRate: taxRate)
            : billAmount
        let tip = TaxTipMath.tipOnly(amount: preTaxAmount, tipRate: tipRate)
        let total = TaxTipMath.total(amount: preTaxAmount, taxRate: taxRate, tipRate: tipRate)

        let dialog = AppIntentFormatting.tipDialog(tip: tip, total: total)
        return .result(value: TipCalculationResult(tip: tip, total: total), dialog: IntentDialog(stringLiteral: dialog))
    }
}

/// A lightweight, non-persisted result so a Shortcuts user can pick out the tip or the total
/// individually when chaining actions, instead of only getting one number back.
struct TipCalculationResult: TransientAppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: LocalizedStringResource("Tip Calculation", comment: "App Intent: Calculate Tip result type name"))
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: AppIntentFormatting.number(total)),
            subtitle: LocalizedStringResource(stringLiteral: AppIntentFormatting.number(tip))
        )
    }

    @Property(title: LocalizedStringResource("Tip", comment: "App Intent: Calculate Tip result 'tip' field title"))
    var tip: Double

    @Property(title: LocalizedStringResource("Total", comment: "App Intent: Calculate Tip result 'total' field title"))
    var total: Double

    init(tip: Double, total: Double) {
        self.tip = tip
        self.total = total
    }

    /// `TransientAppEntity` (this SDK) requires a parameterless initializer; never used to construct
    /// a real result — `TipIntent.perform()` always uses `init(tip:total:)` above.
    init() {
        self.tip = 0
        self.total = 0
    }
}
