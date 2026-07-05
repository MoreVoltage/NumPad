//
//  ConversionUnit.swift
//  NumPad
//
//  App Intents support (App target only — the Keyboard extension is untouched).
//

import AppIntents

/// The full set of convertible units across every `UnitConverter.Category`, exposed as one flat
/// enum so a Siri/Shortcuts user picks "from" and "to" units without first choosing a category.
/// Cross-category requests (e.g. cm → kg) are rejected by `UnitConverter.convert` itself — this
/// enum only mirrors the raw unit strings `UnitConverter` already understands, no new tables.
///
/// Localization note: every `LocalizedStringResource` on this declarative surface
/// (`typeDisplayRepresentation`, `caseDisplayRepresentations`) MUST be a literal — see the note atop
/// `TipIntent.swift` for why (`appintentsmetadataprocessor` statically parses this file at build
/// time and can't evaluate a call like `NSLocalizedString(...)`).
enum ConversionUnit: String, AppEnum {
    case centimeters = "cm"
    case inches = "in"
    case meters = "m"
    case feet = "ft"
    case kilometers = "km"
    case miles = "mi"
    case kilograms = "kg"
    case pounds = "lb"
    case grams = "g"
    case ounces = "oz"
    case celsius = "°C"
    case fahrenheit = "°F"
    case cups = "cup"
    case milliliters = "ml"
    case tablespoons = "tbsp"
    case teaspoons = "tsp"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: LocalizedStringResource("Unit", comment: "App Intent: the ConversionUnit parameter type name"))
    }

    static var caseDisplayRepresentations: [ConversionUnit: DisplayRepresentation] {
        [
            .centimeters: DisplayRepresentation(title: LocalizedStringResource("Centimeters (cm)", comment: "App Intent: unit picker option")),
            .inches: DisplayRepresentation(title: LocalizedStringResource("Inches (in)", comment: "App Intent: unit picker option")),
            .meters: DisplayRepresentation(title: LocalizedStringResource("Meters (m)", comment: "App Intent: unit picker option")),
            .feet: DisplayRepresentation(title: LocalizedStringResource("Feet (ft)", comment: "App Intent: unit picker option")),
            .kilometers: DisplayRepresentation(title: LocalizedStringResource("Kilometers (km)", comment: "App Intent: unit picker option")),
            .miles: DisplayRepresentation(title: LocalizedStringResource("Miles (mi)", comment: "App Intent: unit picker option")),
            .kilograms: DisplayRepresentation(title: LocalizedStringResource("Kilograms (kg)", comment: "App Intent: unit picker option")),
            .pounds: DisplayRepresentation(title: LocalizedStringResource("Pounds (lb)", comment: "App Intent: unit picker option")),
            .grams: DisplayRepresentation(title: LocalizedStringResource("Grams (g)", comment: "App Intent: unit picker option")),
            .ounces: DisplayRepresentation(title: LocalizedStringResource("Ounces (oz)", comment: "App Intent: unit picker option")),
            .celsius: DisplayRepresentation(title: LocalizedStringResource("Celsius (°C)", comment: "App Intent: unit picker option")),
            .fahrenheit: DisplayRepresentation(title: LocalizedStringResource("Fahrenheit (°F)", comment: "App Intent: unit picker option")),
            .cups: DisplayRepresentation(title: LocalizedStringResource("Cups", comment: "App Intent: unit picker option")),
            .milliliters: DisplayRepresentation(title: LocalizedStringResource("Milliliters (ml)", comment: "App Intent: unit picker option")),
            .tablespoons: DisplayRepresentation(title: LocalizedStringResource("Tablespoons (tbsp)", comment: "App Intent: unit picker option")),
            .teaspoons: DisplayRepresentation(title: LocalizedStringResource("Teaspoons (tsp)", comment: "App Intent: unit picker option"))
        ]
    }

    /// Short spoken/display label matching `UnitConverter`'s own unit strings (e.g. "cm", "°F").
    var spokenLabel: String { rawValue }
}
