//
//  QwertyGlideInsertion.swift
//  NumPad
//
//  Pure glide-insertion decisions for the QWERTY page host (glide-and-accuracy design
//  §4.3). Foundation-only value logic, compiled into both the app and Keyboard targets,
//  fully unit-tested (repo convention: keep the host's glue thin, the decisions pure).
//

import Foundation

/// Decisions around inserting a glide-decoded word into the document.
enum QwertyGlideInsertion {

    /// Whether a separating space must be inserted BEFORE the glided word (chaining,
    /// design §4.3): gliding straight after a word ("hello" + glide → "hello world")
    /// supplies the space the user never typed, while a fresh context, an existing
    /// trailing whitespace, or trailing punctuation gets none — the host never doubles
    /// a separator.
    ///
    /// True exactly when the context ends in a letter or a number; a nil/empty context
    /// and anything ending in whitespace or punctuation (apostrophes included — a
    /// trailing apostrophe never earns an inserted separator) return false. Only the
    /// LAST character decides.
    static func leadingSpaceNeeded(before context: String?) -> Bool {
        guard let last = context?.last else { return false }
        return last.isLetter || last.isNumber
    }
}
