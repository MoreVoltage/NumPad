//
//  QwertyGlideInsertionTests.swift
//  NumPadTests
//
//  Unit tests for the pure glide-insertion chaining decision (glide-and-accuracy design
//  §4.3): a separating space is needed before a glided word exactly when the document
//  context ends mid-word (letter or number).
//

import XCTest
@testable import NumPad

final class QwertyGlideInsertionTests: XCTestCase {

    // MARK: - No context: never insert a space

    func testNilContextNeedsNoSpace() {
        XCTAssertFalse(QwertyGlideInsertion.leadingSpaceNeeded(before: nil))
    }

    func testEmptyContextNeedsNoSpace() {
        XCTAssertFalse(QwertyGlideInsertion.leadingSpaceNeeded(before: ""))
    }

    // MARK: - Mid-word context: chain with a space

    func testLetterEndingContextNeedsSpace() {
        XCTAssertTrue(QwertyGlideInsertion.leadingSpaceNeeded(before: "hello"))
    }

    func testSingleLetterContextNeedsSpace() {
        XCTAssertTrue(QwertyGlideInsertion.leadingSpaceNeeded(before: "a"))
    }

    func testNumberEndingContextNeedsSpace() {
        XCTAssertTrue(QwertyGlideInsertion.leadingSpaceNeeded(before: "call 911"))
    }

    func testNonASCIILetterEndingContextNeedsSpace() {
        XCTAssertTrue(QwertyGlideInsertion.leadingSpaceNeeded(before: "café"))
    }

    // MARK: - Boundary-ending context: the separator already exists (or none belongs)

    func testTrailingSpaceNeedsNoSpace() {
        XCTAssertFalse(QwertyGlideInsertion.leadingSpaceNeeded(before: "hello "))
    }

    func testTrailingNewlineNeedsNoSpace() {
        XCTAssertFalse(QwertyGlideInsertion.leadingSpaceNeeded(before: "hello\n"))
    }

    func testTrailingPeriodNeedsNoSpace() {
        XCTAssertFalse(QwertyGlideInsertion.leadingSpaceNeeded(before: "hello."))
    }

    func testTrailingCommaNeedsNoSpace() {
        XCTAssertFalse(QwertyGlideInsertion.leadingSpaceNeeded(before: "hello,"))
    }

    func testTrailingApostropheNeedsNoSpace() {
        // Punctuation per the design decision — even though it can be word-internal, a
        // trailing apostrophe never earns an inserted separator.
        XCTAssertFalse(QwertyGlideInsertion.leadingSpaceNeeded(before: "students'"))
    }

    func testTrailingEmojiNeedsNoSpace() {
        XCTAssertFalse(QwertyGlideInsertion.leadingSpaceNeeded(before: "hi 🙂"))
    }

    // MARK: - Only the LAST character decides

    func testPunctuationInsideWordStillNeedsSpace() {
        XCTAssertTrue(QwertyGlideInsertion.leadingSpaceNeeded(before: "it's done, e.g"))
    }

    func testLetterAfterWhitespaceStillNeedsSpace() {
        XCTAssertTrue(QwertyGlideInsertion.leadingSpaceNeeded(before: "one two"))
    }

    // MARK: - applying(shiftState:to:) — autocap/shift parity for glided words

    func testLowercaseStateLeavesWordUntouched() {
        XCTAssertEqual(QwertyGlideInsertion.applying(shiftState: .lowercase, to: "hello"),
                       "hello")
    }

    func testShiftedStateCapitalizesFirstLetterOnly() {
        XCTAssertEqual(QwertyGlideInsertion.applying(shiftState: .shifted, to: "hello"),
                       "Hello")
    }

    func testCapsLockStateUppercasesWholeWord() {
        XCTAssertEqual(QwertyGlideInsertion.applying(shiftState: .capsLock, to: "hello"),
                       "HELLO")
    }

    func testShiftedStateOnEmptyWordIsEmpty() {
        XCTAssertEqual(QwertyGlideInsertion.applying(shiftState: .shifted, to: ""), "")
    }

    func testShiftedStateOnSingleLetterWord() {
        XCTAssertEqual(QwertyGlideInsertion.applying(shiftState: .shifted, to: "i"), "I")
    }

    func testShiftedStateHandlesNonASCIIFirstLetter() {
        XCTAssertEqual(QwertyGlideInsertion.applying(shiftState: .shifted, to: "école"),
                       "École")
    }

    func testLowercaseStateOnEmptyWordIsEmpty() {
        XCTAssertEqual(QwertyGlideInsertion.applying(shiftState: .lowercase, to: ""), "")
    }
}
