//
//  QwertyNextWordPredictor.swift
//  NumPad
//
//  HARNESS ARM ONLY (research plan Task 8) — compiled into the NumPad APP
//  target exclusively, like `QwertySymSpellCorrector`; deliberately NOT in the
//  Keyboard extension. This predictor ships nowhere until/unless it clears the
//  pre-registered adoption gates (+15pp absolute top-1 hit-rate over the
//  completion baseline or an equivalent KSR gain, ≤15MB resident, ≤16ms p95);
//  Task 9 owns any wiring decision.
//
//  Bigram next-word lookup over a packed blob generated offline by
//  `tools/make_qwerty_bigrams.swift` from the CC BY 4.0 experimental en_US
//  wordlist in Helium314's aosp-dictionaries (provenance:
//  `tools/data/bigrams_provenance.txt` and the "Next-word bigram source"
//  section of `tools/data/eval/README.md`). Words are stored as ranks into the
//  production `QwertyFrequencyLexicon` — the blob carries no strings at all.
//
//  **Packed format** (all integers little-endian):
//
//  ```
//  "NPBG" (4 bytes) | version UInt8 = 1 | headCount UInt32
//  heads (variable length, sorted by headRank STRICTLY ascending):
//    headRank UInt16 | contCount UInt8 | contCount × contRank UInt16
//  ```
//
//  Continuations are stored best-first (the source's own frequency order), so
//  `predictions(after:)` is a binary search over the head records plus a
//  sequential read — no per-query allocation beyond the result array.
//
//  **Corrupt data never crashes.** Same trust-boundary discipline as
//  `QwertyFrequencyLexicon.init(data:)`: the header, the record walk, and the
//  strictly-ascending head order are all validated up front; any violation
//  (bad magic/version, truncation, overstated count, unsorted heads) degrades
//  to an empty predictor — every lookup returns `[]` — rather than trapping.
//
//  Foundation-only on purpose: the offline generator tool compiles this same
//  file standalone with swiftc, so it must never import UIKit or anything
//  app-specific.
//

import Foundation

struct QwertyNextWordPredictor {

    /// "NPBG" magic prefix identifying the blob.
    private static let magic: [UInt8] = [0x4E, 0x50, 0x42, 0x47]
    /// The only format version this reader understands.
    private static let version: UInt8 = 1
    /// magic (4) + version (1) + headCount (4).
    private static let headerSize = 9
    /// Ranks are stored as `UInt16`, matching the lexicon's rank ceiling.
    private static let maxRank = Int(UInt16.max)
    /// Default prediction window — mirrors the suggestion bar's three slots.
    /// Not `private`: referenced from the `predictions(after:max:)` default
    /// argument, which callers in other files inline.
    static let defaultMax = 3

    /// The packed blob itself — the resident structure; never inflated.
    private let data: Data
    /// Byte offset of each head record, in headRank-ascending order (the
    /// binary-search index). Empty when the blob failed validation.
    private let recordOffsets: [Int]
    /// rank → word table from the lexicon (`nil` only for rank gaps in a
    /// corrupt lexicon blob). Built once at init — the same deliberate
    /// inflation `QwertySymSpellCorrector` performs; empty when the bigram
    /// blob failed validation so a corrupt blob costs nothing.
    private let wordsByRank: [String?]
    /// Rank lookup for the head word.
    private let lexicon: QwertyFrequencyLexicon

    // MARK: - Init

    /// Wraps `data`, validating the header and every head record up front.
    /// Invalid or truncated data yields an empty predictor — every lookup
    /// returns `[]` — instead of crashing.
    init(data: Data, lexicon: QwertyFrequencyLexicon) {
        self.data = data
        self.lexicon = lexicon
        let offsets = Self.validatedRecordOffsets(in: data)
        self.recordOffsets = offsets
        self.wordsByRank = offsets.isEmpty ? [] : Self.rankTable(from: lexicon)
    }

    // MARK: - API

    /// Up to `max` next-word predictions after `word`, best first (the
    /// source's own frequency order). Lowercase in/out — the head is folded
    /// before lookup and the lexicon stores lowercased words. Unknown head,
    /// head without bigrams, or an invalid blob → `[]`.
    func predictions(after word: String, max limit: Int = QwertyNextWordPredictor.defaultMax)
        -> [String] {
        guard limit > 0, !recordOffsets.isEmpty else { return [] }
        let head = word.lowercased()
        guard !head.isEmpty,
              let headRank = lexicon.rank(of: head),
              headRank <= Self.maxRank,
              let recordOffset = recordOffset(forHeadRank: headRank),
              let continuationCount = readByte(at: recordOffset + 2).map(Int.init) else {
            return []
        }
        var predictions: [String] = []
        predictions.reserveCapacity(min(limit, continuationCount))
        for index in 0..<continuationCount {
            guard predictions.count < limit else { break }
            guard let continuationRank = readUInt16(at: recordOffset + 3 + 2 * index),
                  continuationRank < wordsByRank.count,
                  let continuation = wordsByRank[continuationRank] else { continue }
            predictions.append(continuation)
        }
        return predictions
    }

    // MARK: - Encoding (shared by unit tests and tools/make_qwerty_bigrams.swift)

    /// Packs `heads` into the binary format above.
    ///
    /// Normalization: heads with ranks outside `0...UInt16.max` are skipped;
    /// duplicate head ranks keep their FIRST occurrence; continuation ranks
    /// outside `0...UInt16.max` and duplicate continuations within a head are
    /// dropped; continuations are capped at 255 per head (the `UInt8` count
    /// ceiling); heads left with zero continuations are dropped entirely.
    /// Records are sorted by headRank ascending so lookups can binary-search.
    static func encode(heads: [(headRank: Int, continuationRanks: [Int])]) -> Data {
        var seenHeads = Set<Int>()
        var records: [(headRank: Int, continuations: [Int])] = []
        for head in heads {
            guard (0...maxRank).contains(head.headRank),
                  seenHeads.insert(head.headRank).inserted else { continue }
            var seenContinuations = Set<Int>()
            let continuations = head.continuationRanks
                .filter { (0...maxRank).contains($0) && seenContinuations.insert($0).inserted }
                .prefix(Int(UInt8.max))
            guard !continuations.isEmpty else { continue }
            records.append((headRank: head.headRank, continuations: Array(continuations)))
        }
        records.sort { $0.headRank < $1.headRank }

        var blob = Data()
        blob.append(contentsOf: magic)
        blob.append(version)
        appendUInt32(UInt32(records.count), to: &blob)
        for record in records {
            appendUInt16(UInt16(record.headRank), to: &blob)
            blob.append(UInt8(record.continuations.count))
            for continuation in record.continuations {
                appendUInt16(UInt16(continuation), to: &blob)
            }
        }
        return blob
    }

    // MARK: - Validation walk

    /// Walks the whole blob once: header check, then every head record
    /// bounds-checked and headRank verified strictly ascending. Returns the
    /// per-record byte offsets, or `[]` when ANY check fails — all-or-nothing,
    /// so a partially readable blob never serves partial answers.
    private static func validatedRecordOffsets(in data: Data) -> [Int] {
        guard data.count >= headerSize,
              magic.enumerated().allSatisfy({ data[data.startIndex + $0.offset] == $0.element }),
              data[data.startIndex + 4] == version else { return [] }
        let headCount = Int(data[data.startIndex + 5])
            | (Int(data[data.startIndex + 6]) << 8)
            | (Int(data[data.startIndex + 7]) << 16)
            | (Int(data[data.startIndex + 8]) << 24)
        guard headCount > 0 else { return [] }

        var offsets: [Int] = []
        offsets.reserveCapacity(headCount)
        var cursor = headerSize
        var previousHeadRank = -1
        for _ in 0..<headCount {
            // headRank (2) + contCount (1) must fit before reading them.
            guard cursor + 3 <= data.count else { return [] }
            let headRank = Int(data[data.startIndex + cursor])
                | (Int(data[data.startIndex + cursor + 1]) << 8)
            let continuationCount = Int(data[data.startIndex + cursor + 2])
            guard headRank > previousHeadRank, continuationCount > 0,
                  cursor + 3 + 2 * continuationCount <= data.count else { return [] }
            offsets.append(cursor)
            previousHeadRank = headRank
            cursor += 3 + 2 * continuationCount
        }
        return offsets
    }

    /// rank → word table via the lexicon's one-time load pass (see
    /// `QwertyFrequencyLexicon.allEntries()`).
    private static func rankTable(from lexicon: QwertyFrequencyLexicon) -> [String?] {
        let entries = lexicon.allEntries()
        let maxEntryRank = entries.map(\.rank).max() ?? -1
        guard maxEntryRank >= 0 else { return [] }
        var table = [String?](repeating: nil, count: maxEntryRank + 1)
        for entry in entries where entry.rank >= 0 {
            table[entry.rank] = entry.word
        }
        return table
    }

    // MARK: - Binary search

    /// Offset of the head record whose headRank equals `headRank`, or `nil`.
    /// Valid because init verified the records are strictly ascending.
    private func recordOffset(forHeadRank headRank: Int) -> Int? {
        var low = 0
        var high = recordOffsets.count - 1
        while low <= high {
            let mid = (low + high) / 2
            guard let midRank = readUInt16(at: recordOffsets[mid]) else { return nil }
            if midRank == headRank { return recordOffsets[mid] }
            if midRank < headRank { low = mid + 1 } else { high = mid - 1 }
        }
        return nil
    }

    // MARK: - Bounds-checked reads

    private func readByte(at offset: Int) -> UInt8? {
        guard offset >= 0, offset < data.count else { return nil }
        return data[data.startIndex + offset]
    }

    private func readUInt16(at offset: Int) -> Int? {
        guard let low = readByte(at: offset), let high = readByte(at: offset + 1) else {
            return nil
        }
        return Int(low) | (Int(high) << 8)
    }

    private static func appendUInt16(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8(value >> 8))
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 24) & 0xFF))
    }
}
