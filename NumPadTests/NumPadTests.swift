import XCTest
@testable import NumPad

final class NumPadTests: XCTestCase {
    func testTestBundleLoads() {
        XCTAssertNotNil(Bundle(for: Self.self).bundleIdentifier)
    }
}

// MARK: - Calculator

final class CalculatorTests: XCTestCase {
    func testBasicArithmetic() {
        XCTAssertEqual(Calculator.evaluate("2+3"), 5)
        XCTAssertEqual(Calculator.evaluate("10-4"), 6)
        XCTAssertEqual(Calculator.evaluate("6*7"), 42)
        XCTAssertEqual(Calculator.evaluate("20/4"), 5)
    }

    func testPrecedenceAndParentheses() {
        XCTAssertEqual(Calculator.evaluate("2+3*4"), 14)
        XCTAssertEqual(Calculator.evaluate("(2+3)*4"), 20)
        XCTAssertEqual(Calculator.evaluate("2*(3+4)-1"), 13)
    }

    func testUnaryMinus() {
        XCTAssertEqual(Calculator.evaluate("-5+3"), -2)
        XCTAssertEqual(Calculator.evaluate("3*-2"), -6)
        XCTAssertEqual(Calculator.evaluate("-(2+3)"), -5)
    }

    func testDecimalsAndAltOperators() {
        XCTAssertEqual(Calculator.evaluate("1.5+2.5"), 4)
        XCTAssertEqual(Calculator.evaluate("3×4"), 12)
        XCTAssertEqual(Calculator.evaluate("8÷2"), 4)
    }

    func testLocaleDecimalSeparator() {
        XCTAssertEqual(Calculator.evaluate("1,5+2,5", decimalSeparator: ","), 4)
    }

    func testDivisionByZeroReturnsNil() {
        XCTAssertNil(Calculator.evaluate("5/0"))
        XCTAssertNil(Calculator.evaluate("5%0"))
    }

    func testMalformedReturnsNil() {
        XCTAssertNil(Calculator.evaluate(""))
        XCTAssertNil(Calculator.evaluate("2+"))
        XCTAssertNil(Calculator.evaluate("(2+3"))
        XCTAssertNil(Calculator.evaluate("2+3)"))
        XCTAssertNil(Calculator.evaluate("abc"))
        XCTAssertNil(Calculator.evaluate("2 3"))
    }

    func testFormatStripsTrailingZero() {
        XCTAssertEqual(Calculator.format(5), "5")
        XCTAssertEqual(Calculator.format(2.5), "2.5")
        XCTAssertEqual(Calculator.format(2.5, decimalSeparator: ","), "2,5")
    }
}

// MARK: - Unit converter

final class UnitConverterTests: XCTestCase {
    func testLength() {
        XCTAssertEqual(UnitConverter.convert(100, from: "cm", to: "m")!, 1, accuracy: 1e-9)
        XCTAssertEqual(UnitConverter.convert(1, from: "in", to: "cm")!, 2.54, accuracy: 1e-9)
        XCTAssertEqual(UnitConverter.convert(1, from: "mi", to: "km")!, 1.609344, accuracy: 1e-9)
    }

    func testMass() {
        XCTAssertEqual(UnitConverter.convert(1, from: "kg", to: "g")!, 1000, accuracy: 1e-6)
        XCTAssertEqual(UnitConverter.convert(1, from: "lb", to: "kg")!, 0.45359237, accuracy: 1e-9)
    }

    func testTemperature() {
        XCTAssertEqual(UnitConverter.convert(0, from: "°C", to: "°F")!, 32, accuracy: 1e-9)
        XCTAssertEqual(UnitConverter.convert(100, from: "°C", to: "°F")!, 212, accuracy: 1e-9)
        XCTAssertEqual(UnitConverter.convert(32, from: "°F", to: "°C")!, 0, accuracy: 1e-9)
    }

    func testSameUnitAndUnknown() {
        XCTAssertEqual(UnitConverter.convert(5, from: "m", to: "m"), 5)
        XCTAssertNil(UnitConverter.convert(5, from: "m", to: "kg"))
        XCTAssertNil(UnitConverter.convert(5, from: "bogus", to: "m"))
    }
}

// MARK: - Tax/Tip math

final class TaxTipMathTests: XCTestCase {
    func testTotalAppliesTaxAndTipOnPreTaxAmount() {
        XCTAssertEqual(TaxTipMath.total(amount: 100, taxRate: 0.10, tipRate: 0.20), 130, accuracy: 1e-9)
        XCTAssertEqual(TaxTipMath.total(amount: 50, taxRate: 0, tipRate: 0.15), 57.5, accuracy: 1e-9)
    }

    func testZeroRatesReturnAmount() {
        XCTAssertEqual(TaxTipMath.total(amount: 42, taxRate: 0, tipRate: 0), 42, accuracy: 1e-9)
    }

    func testTipOnlyIgnoresTax() {
        XCTAssertEqual(TaxTipMath.tipOnly(amount: 100, tipRate: 0.18), 18, accuracy: 1e-9)
        XCTAssertEqual(TaxTipMath.tipOnly(amount: 100, tipRate: 0), 0, accuracy: 1e-9)
    }
}

// MARK: - Version comparison (grandfathering)

final class VersionComparisonTests: XCTestCase {
    func testOlderVersionsAreLess() {
        XCTAssertTrue(StoreManager.isVersion("1.0", lessThan: "1.7.0"))
        XCTAssertTrue(StoreManager.isVersion("1.6.9", lessThan: "1.7.0"))
        XCTAssertTrue(StoreManager.isVersion("1.5.4", lessThan: "1.7.0"))
    }

    func testEqualOrNewerAreNotLess() {
        XCTAssertFalse(StoreManager.isVersion("1.7.0", lessThan: "1.7.0"))
        XCTAssertFalse(StoreManager.isVersion("1.7.1", lessThan: "1.7.0"))
        XCTAssertFalse(StoreManager.isVersion("2.0", lessThan: "1.7.0"))
        XCTAssertFalse(StoreManager.isVersion("1.10", lessThan: "1.7.0"))
    }

    func testUnparseableFailsClosed() {
        // An unparseable version must NOT be treated as older (no free grandfathering on bad input).
        XCTAssertFalse(StoreManager.isVersion("", lessThan: "1.7.0"))
        XCTAssertFalse(StoreManager.isVersion("abc", lessThan: "1.7.0"))
    }
}
