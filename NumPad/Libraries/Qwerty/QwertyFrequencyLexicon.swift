//
//  QwertyFrequencyLexicon.swift
//  NumPad
//
//  Packed English word-frequency lexicon for the QWERTY page: rank lookup and
//  candidate re-ranking over a compact binary blob. Shared foundation for the
//  autocorrect re-ranker and the glide-typing decoder's frequency prior.
//  Foundation-only on purpose: the offline generator tool
//  (tools/make_qwerty_lexicon.swift) compiles this same file standalone with
//  swiftc, so it must never import UIKit or anything app-specific.
//

import Foundation

/// Frequency-ranked word lexicon backed by a packed `Data` blob.
///
/// **Memory constraint (why this isn't a `Dictionary`).** The keyboard extension runs under
/// a ~50MB memory ceiling. Inflating a 50k-word corpus into `[String: Int]` costs several MB
/// of heap (String + hash-table overhead per entry) and a load-time parse. Instead the blob
/// produced by `encode(rankedWords:)` — about 700KB for the bundled en_50k corpus — **is** the
/// resident structure: lookups binary-search the offset table in place, comparing raw UTF-8
/// bytes, so the only per-lookup allocation is the query word's byte array. `allEntries()`
/// (and its `allWords()` convenience) is the deliberate exception: it inflates the full word
/// list (~49k Strings, roughly 1–2MB) for the glide decoder's one-time load pass — every
/// other path stays on the packed bytes.
///
/// **Packed format** (all integers little-endian):
///
/// ```
/// "NPLX" (4 bytes) | version UInt8 = 1 | count UInt32
/// offsets: count × UInt32            (byte offset of each record, from blob start)
/// records (sorted by UTF-8 byte order of word):
///   length UInt8 | word UTF-8 bytes | rank UInt16   (rank 0 = most frequent)
/// ```
///
/// **Corrupt data never crashes.** The bundle is a trust boundary: `init(data:)` validates
/// magic/version/count/offset-table bounds up front, and every record read is bounds-checked
/// again at access time, so a truncated or garbage blob degrades to an empty lexicon
/// (`rank(of:)` returns `nil` for everything) rather than trapping inside the extension.
struct QwertyFrequencyLexicon {

    /// "NPLX" magic prefix identifying the blob.
    private static let magic: [UInt8] = [0x4E, 0x50, 0x4C, 0x58]
    /// The only format version this reader understands.
    private static let version: UInt8 = 1
    /// magic (4) + version (1) + count (4).
    private static let headerSize = 9
    /// Ranks are stored as `UInt16`, so at most 65,536 words (ranks 0...65535) fit.
    private static let maxWordCount = Int(UInt16.max) + 1

    /// The packed blob itself — the resident structure; never inflated.
    private let data: Data
    /// Number of records, as validated against the blob's actual size (0 when invalid).
    private let recordCount: Int

    /// Loads the bundled `qwerty_lexicon_en.bin` blob from `bundle`. Only the Keyboard
    /// extension target carries the resource — in any other bundle (app target, unit
    /// tests) this degrades to an empty lexicon, making `rerank(_:)` the identity,
    /// rather than failing. Memory-mapped (`.mappedIfSafe`) so the ~700KB blob doesn't
    /// count fully against the extension's ~50MB ceiling.
    init(bundled bundle: Bundle) {
        guard let url = bundle.url(forResource: "qwerty_lexicon_en", withExtension: "bin") else {
            #if DEBUG
            // Surfaces a packaging regression (blob dropped from the Keyboard target's
            // Resources phase) in development; for bundles that legitimately lack the
            // resource (app target, unit tests) the identity fallback is the intent.
            print("QwertyFrequencyLexicon: qwerty_lexicon_en.bin not found in "
                  + "\(bundle.bundleURL.lastPathComponent) — frequency re-ranking disabled")
            #endif
            self.init(data: Data())
            return
        }
        self.init(data: (try? Data(contentsOf: url, options: .mappedIfSafe)) ?? Data())
    }

    /// Wraps `data`, validating the header. Invalid or truncated data yields an empty
    /// lexicon — every lookup misses — instead of crashing.
    init(data: Data) {
        self.data = data
        guard data.count >= Self.headerSize,
              Self.magic.enumerated().allSatisfy({ data[data.startIndex + $0.offset] == $0.element }),
              data[data.startIndex + 4] == Self.version else {
            self.recordCount = 0
            return
        }
        let count = Int(data[data.startIndex + 5])
            | (Int(data[data.startIndex + 6]) << 8)
            | (Int(data[data.startIndex + 7]) << 16)
            | (Int(data[data.startIndex + 8]) << 24)
        let offsetsEnd = Self.headerSize + 4 * count
        self.recordCount = (count >= 0 && offsetsEnd <= data.count) ? count : 0
    }

    // MARK: - Lookup

    /// Frequency rank of `word` (0 = most frequent), or `nil` when unknown.
    /// Case-insensitive: the blob stores lowercased words, so the query is lowercased too.
    func rank(of word: String) -> Int? {
        guard recordCount > 0 else { return nil }
        let query = Array(word.lowercased().utf8)
        guard !query.isEmpty else { return nil }

        var low = 0
        var high = recordCount - 1
        while low <= high {
            let mid = (low + high) / 2
            guard let record = record(at: mid) else { return nil }
            switch compare(query, toWordAt: record.wordStart, length: record.wordLength) {
            case .orderedSame: return record.rank
            case .orderedAscending: high = mid - 1
            case .orderedDescending: low = mid + 1
            }
        }
        return nil
    }

    /// Reorders `candidates` by ascending frequency rank; words the lexicon doesn't know
    /// sort after all known words and keep their input order (stable), as do rank ties.
    func rerank(_ candidates: [String]) -> [String] {
        candidates.enumerated()
            .map { (order: $0.offset, word: $0.element, rank: rank(of: $0.element) ?? Int.max) }
            .sorted { ($0.rank, $0.order) < ($1.rank, $1.order) }
            .map(\.word)
    }

    /// Reorders only the candidates the corpus KNOWS — by ascending rank among themselves,
    /// within the index slots those known words occupied; candidates the corpus does NOT
    /// know keep their exact positions (rank ties keep input order).
    ///
    /// Policy: frequency refines ordering among words the corpus knows; it never overrides
    /// the checker's judgment about words the corpus doesn't know — a wrong correction is
    /// worse than a missed one. Use this for `UITextChecker`'s guesses (already
    /// likelihood-ranked; a full `rerank` would demote a correct out-of-corpus guess such
    /// as a proper noun to last), and the full `rerank` for its alphabetical completions.
    func rerankKnown(_ candidates: [String]) -> [String] {
        let ranks = candidates.map(rank(of:))
        let knownSlots = candidates.indices.filter { ranks[$0] != nil }
        let reorderedKnown = knownSlots
            .sorted { (ranks[$0] ?? .max, $0) < (ranks[$1] ?? .max, $1) }
            .map { candidates[$0] }
        var result = candidates
        for (slot, word) in zip(knownSlots, reorderedKnown) { result[slot] = word }
        return result
    }

    /// Every word in the lexicon, in record (UTF-8 byte) order — a convenience over
    /// `allEntries()` for callers that don't need ranks.
    func allWords() -> [String] {
        allEntries().map(\.word)
    }

    /// Every (word, rank) pair in the lexicon, in record (UTF-8 byte) order — the glide
    /// decoder's one-time load pass. The rank is read straight off each record during the
    /// walk (it's the two bytes after the word bytes), so callers never need a per-word
    /// `rank(of:)` binary search. An out-of-bounds record ends the walk early rather than
    /// trapping; a record whose bytes aren't valid UTF-8 is skipped and the walk continues.
    func allEntries() -> [(word: String, rank: Int)] {
        var entries: [(word: String, rank: Int)] = []
        entries.reserveCapacity(recordCount)
        for index in 0..<recordCount {
            guard let record = record(at: index) else { return entries }
            let start = data.startIndex + record.wordStart
            guard let word = String(data: data[start..<(start + record.wordLength)],
                                    encoding: .utf8) else { continue }
            entries.append((word: word, rank: record.rank))
        }
        return entries
    }

    // MARK: - Encoding (shared by unit tests and tools/make_qwerty_lexicon.swift)

    /// Packs `rankedWords` (most frequent first) into the binary format above.
    ///
    /// Words are lowercased and deduplicated (first occurrence wins its rank); empty words
    /// and words longer than 255 UTF-8 bytes are skipped; encoding stops at 65,536 words —
    /// the `UInt16` rank ceiling. Records are sorted by raw UTF-8 byte order so `rank(of:)`
    /// can binary-search without decoding strings.
    static func encode(rankedWords: [String]) -> Data {
        var seen = Set<[UInt8]>()
        var records: [(word: [UInt8], rank: Int)] = []
        for word in rankedWords {
            guard records.count < maxWordCount else { break }
            let bytes = Array(word.lowercased().utf8)
            guard !bytes.isEmpty, bytes.count <= Int(UInt8.max),
                  seen.insert(bytes).inserted else { continue }
            records.append((word: bytes, rank: records.count))
        }
        records.sort { $0.word.lexicographicallyPrecedes($1.word) }

        var offsets = Data(capacity: 4 * records.count)
        var body = Data()
        var nextRecordOffset = headerSize + 4 * records.count
        for record in records {
            appendUInt32(UInt32(nextRecordOffset), to: &offsets)
            body.append(UInt8(record.word.count))
            body.append(contentsOf: record.word)
            appendUInt16(UInt16(record.rank), to: &body)
            nextRecordOffset += 1 + record.word.count + 2
        }

        var blob = Data(capacity: headerSize + offsets.count + body.count)
        blob.append(contentsOf: magic)
        blob.append(version)
        appendUInt32(UInt32(records.count), to: &blob)
        blob.append(offsets)
        blob.append(body)
        return blob
    }

    // MARK: - Bounds-checked record access

    /// Word-bytes location and rank for the record at `index` in the offset table, or `nil`
    /// when any part of it falls outside the blob (corrupt/truncated data).
    private func record(at index: Int) -> (wordStart: Int, wordLength: Int, rank: Int)? {
        guard index >= 0, index < recordCount,
              let recordOffset = readUInt32(at: Self.headerSize + 4 * index),
              let length = readByte(at: recordOffset).map(Int.init),
              let rank = readUInt16(at: recordOffset + 1 + length) else { return nil }
        // The rank field sits after the word bytes, so a successful rank read proves the
        // whole record (length byte, word bytes, rank) is inside the blob.
        return (wordStart: recordOffset + 1, wordLength: length, rank: rank)
    }

    /// Byte-lexicographic comparison of `query` against the stored word at `wordStart`,
    /// performed directly on the blob — no String is decoded.
    private func compare(_ query: [UInt8], toWordAt wordStart: Int, length: Int) -> ComparisonResult {
        for index in 0..<min(query.count, length) {
            let storedByte = data[data.startIndex + wordStart + index]
            if query[index] != storedByte {
                return query[index] < storedByte ? .orderedAscending : .orderedDescending
            }
        }
        if query.count == length { return .orderedSame }
        return query.count < length ? .orderedAscending : .orderedDescending
    }

    private func readByte(at offset: Int) -> UInt8? {
        guard offset >= 0, offset < data.count else { return nil }
        return data[data.startIndex + offset]
    }

    private func readUInt16(at offset: Int) -> Int? {
        guard let low = readByte(at: offset), let high = readByte(at: offset + 1) else { return nil }
        return Int(low) | (Int(high) << 8)
    }

    private func readUInt32(at offset: Int) -> Int? {
        guard let b0 = readByte(at: offset), let b1 = readByte(at: offset + 1),
              let b2 = readByte(at: offset + 2), let b3 = readByte(at: offset + 3) else { return nil }
        return Int(b0) | (Int(b1) << 8) | (Int(b2) << 16) | (Int(b3) << 24)
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
