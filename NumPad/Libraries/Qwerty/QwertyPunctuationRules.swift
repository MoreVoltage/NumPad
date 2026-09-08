import Foundation

enum QwertyPunctuationRules {
    struct EditDecision: Equatable {
        let deletions: Int
        let insertion: String
    }

    static func decision(before context: String?, inserting text: String,
                         smartQuotes: Bool = true,
                         adjustsSpacing: Bool = true) -> EditDecision {
        guard let context = context, !text.isEmpty else {
            return EditDecision(deletions: 0, insertion: text)
        }
        // Space before . , ? ! : ;
        if adjustsSpacing, text.count == 1, ".,?!:;".contains(text), context.hasSuffix(" ") {
            return EditDecision(deletions: 1, insertion: text)
        }
        // Straight to curly apostrophe in contractions: letter + ' + letter-bound
        if smartQuotes, text == "'", let last = context.last, last.isLetter {
            return EditDecision(deletions: 0, insertion: "\u{2019}")
        }
        // Second opening quote becomes closing based on local unpaired count.
        if smartQuotes, text == "\"" {
            let opens = context.filter { $0 == "\u{201C}" }.count
            let closes = context.filter { $0 == "\u{201D}" }.count
            if opens > closes {
                return EditDecision(deletions: 0, insertion: "\u{201D}")
            }
            return EditDecision(deletions: 0, insertion: "\u{201C}")
        }
        return EditDecision(deletions: 0, insertion: text)
    }
}
