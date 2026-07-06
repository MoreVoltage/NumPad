import XCTest
import UIKit
@testable import NumPad

/// `KeyGlyph` is the shared (app + Keyboard target) source of truth for the bottom-row
/// switch-key glyph identifiers. It exists specifically so this invariant — the pack-switch key
/// must never look like the system keyboard-switch "globe" key — is unit-testable from the app
/// target, even though the keys that actually render it (`Item`, `Cell`) live only in the
/// Keyboard extension target. See Keyboard/Views/Cell.swift and Keyboard/Libraries/Item.swift.
final class KeyGlyphTests: XCTestCase {

    // MARK: distinctness — the bug this test guards against
    func testPackSwitchGlyphIsDistinctFromGlobe() {
        XCTAssertNotEqual(KeyGlyph.packSwitch, "globe",
                           "the pack-switch key must never reuse the system globe's glyph identifier")
    }

    func testPackSwitchGlyphIsNotEmpty() {
        XCTAssertFalse(KeyGlyph.packSwitch.isEmpty)
    }

    // MARK: the identifier must resolve to a real, renderable SF Symbol
    //
    // `Cell.configure` falls back to `UIImage(systemName:)` for image keys with no bundled asset
    // (see Cell.swift) — exactly how the pack-switch key renders today. A typo'd or retired SF
    // Symbol name would silently render a blank key, so this test resolves the symbol directly.
    func testPackSwitchGlyphResolvesToARealSFSymbol() {
        XCTAssertNotNil(UIImage(systemName: KeyGlyph.packSwitch),
                         "\(KeyGlyph.packSwitch) must be a valid SF Symbol name")
    }

    func testGlobeGlyphStillResolvesToARealSFSymbol() {
        // Sanity check on the comparison baseline: the true keyboard-switch key keeps rendering
        // the system "globe" glyph unchanged (see Item.swift / Cell.swift).
        XCTAssertNotNil(UIImage(systemName: "globe"))
    }
}
