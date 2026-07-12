//
//  make_qwerty_lexicon.swift
//  NumPad tools
//
//  Offline generator for the packed QWERTY frequency lexicon. Reads a hermitdave
//  FrequencyWords corpus ("word count" per line, most frequent first), filters to
//  plain lowercase words, and packs them with the exact same encoder the app uses
//  (QwertyFrequencyLexicon.encode) so the on-device reader round-trips by construction.
//
//  Build & run (from the repo root):
//    swiftc -o /tmp/mklex tools/make_qwerty_lexicon.swift \
//        NumPad/Libraries/Qwerty/QwertyFrequencyLexicon.swift
//    /tmp/mklex tools/data/en_50k.txt Keyboard/Resources/qwerty_lexicon_en.bin
//

import Foundation

@main
struct MakeQwertyLexicon {

    /// Words must be 1–24 characters of `[a-z'-]` only — anything else (digits,
    /// punctuation-only tokens, non-ASCII) is corpus noise for a typing lexicon.
    private static let maxWordLength = 24
    private static let allowedScalars = Set("abcdefghijklmnopqrstuvwxyz'-".unicodeScalars)

    static func main() {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else {
            FileHandle.standardError.write(Data(
                "usage: \(arguments.first ?? "mklex") <corpus.txt> <output.bin>\n".utf8))
            exit(1)
        }
        let inputPath = arguments[1]
        let outputPath = arguments[2]

        guard let corpus = try? String(contentsOfFile: inputPath, encoding: .utf8) else {
            FileHandle.standardError.write(Data("error: cannot read \(inputPath)\n".utf8))
            exit(1)
        }

        let rankedWords = rankedWords(fromCorpus: corpus)
        guard !rankedWords.isEmpty else {
            FileHandle.standardError.write(Data("error: no usable words in \(inputPath)\n".utf8))
            exit(1)
        }

        let blob = QwertyFrequencyLexicon.encode(rankedWords: rankedWords)
        do {
            try blob.write(to: URL(fileURLWithPath: outputPath))
        } catch {
            FileHandle.standardError.write(Data(
                "error: cannot write \(outputPath): \(error.localizedDescription)\n".utf8))
            exit(1)
        }
        print("wrote \(rankedWords.count) words (\(blob.count) bytes) to \(outputPath)")
    }

    /// Extracts words in corpus (frequency) order: first whitespace-separated token of each
    /// line, lowercased, kept only when it matches `^[a-z'-]{1,24}$`.
    private static func rankedWords(fromCorpus corpus: String) -> [String] {
        corpus
            .split(separator: "\n")
            .compactMap { line in
                guard let token = line.split(separator: " ").first else { return nil }
                let word = token.lowercased()
                guard isUsableWord(word) else { return nil }
                return word
            }
    }

    private static func isUsableWord(_ word: String) -> Bool {
        guard !word.isEmpty, word.count <= maxWordLength else { return false }
        return word.unicodeScalars.allSatisfy { allowedScalars.contains($0) }
    }
}
