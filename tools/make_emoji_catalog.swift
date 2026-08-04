#!/usr/bin/env swift

import CryptoKit
import Foundation

private let unicodeVersion = "14.0"
private let cldrVersion = "40"
private let resourceLimit = 1_048_576

private struct Arguments {
    let emojiTest: URL
    let annotations: URL
    let derivedAnnotations: URL
    let license: URL
    let outputDirectory: URL

    init() throws {
        var values: [String: String] = [:]
        var iterator = CommandLine.arguments.dropFirst().makeIterator()
        while let flag = iterator.next() {
            guard flag.hasPrefix("--"), let value = iterator.next() else {
                throw GeneratorError.usage
            }
            values[String(flag.dropFirst(2))] = value
        }

        guard
            let emojiTest = values["emoji-test"],
            let annotations = values["annotations"],
            let derivedAnnotations = values["derived-annotations"],
            let license = values["license"],
            let outputDirectory = values["output-dir"],
            values.count == 5
        else {
            throw GeneratorError.usage
        }

        self.emojiTest = URL(fileURLWithPath: emojiTest)
        self.annotations = URL(fileURLWithPath: annotations)
        self.derivedAnnotations = URL(fileURLWithPath: derivedAnnotations)
        self.license = URL(fileURLWithPath: license)
        self.outputDirectory = URL(fileURLWithPath: outputDirectory, isDirectory: true)
    }
}

private enum GeneratorError: Error, CustomStringConvertible {
    case usage
    case invalidEmojiVersion
    case invalidCLDRVersion(URL)
    case unknownGroup(String)
    case malformedEmojiLine(String)
    case duplicateSequence(String)
    case missingBaseForVariant(String)
    case malformedAnnotations(URL)
    case resourceTooLarge(String, Int)

    var description: String {
        switch self {
        case .usage:
            return "usage: make_emoji_catalog.swift --emoji-test PATH --annotations PATH --derived-annotations PATH --license PATH --output-dir DIR"
        case .invalidEmojiVersion:
            return "emoji-test.txt is not Unicode Emoji \(unicodeVersion)"
        case let .invalidCLDRVersion(url):
            return "CLDR input is not version \(cldrVersion): \(url.path)"
        case let .unknownGroup(group):
            return "unknown Unicode emoji group: \(group)"
        case let .malformedEmojiLine(line):
            return "malformed fully-qualified emoji line: \(line)"
        case let .duplicateSequence(sequence):
            return "duplicate fully-qualified sequence: \(sequence)"
        case let .missingBaseForVariant(sequence):
            return "skin-tone variant has no fully-qualified base: \(sequence)"
        case let .malformedAnnotations(url):
            return "malformed CLDR annotation payload: \(url.path)"
        case let .resourceTooLarge(name, size):
            return "generated resource exceeds \(resourceLimit) bytes: \(name) is \(size) bytes"
        }
    }
}

private struct ParsedEmoji {
    let sequence: String
    let category: String
    let fallbackName: String
}

private struct BrowseEntry: Codable {
    let sequence: String
    let category: String
    var variantIndices: [Int]
}

private struct BrowsePayload: Codable {
    let unicodeVersion: String
    let entries: [BrowseEntry]
}

private struct SearchAnnotation: Codable {
    let catalogIndex: Int
    let name: String
    let keywords: [String]
}

private struct SearchPayload: Codable {
    let cldrVersion: String
    let locale: String
    let annotations: [SearchAnnotation]
}

private struct CLDRAnnotation {
    let name: String?
    let keywords: [String]
}

private func category(for group: String) throws -> String? {
    switch group {
    case "Smileys & Emotion": return "smileys"
    case "People & Body": return "people"
    case "Component": return nil
    case "Animals & Nature": return "animals"
    case "Food & Drink": return "food"
    case "Travel & Places": return "travel"
    case "Activities": return "activities"
    case "Objects": return "objects"
    case "Symbols": return "symbols"
    case "Flags": return "flags"
    default: throw GeneratorError.unknownGroup(group)
    }
}

private func parseEmojiTest(_ data: Data) throws -> [ParsedEmoji] {
    guard
        let text = String(data: data, encoding: .utf8),
        text.contains("# Version: \(unicodeVersion)")
    else {
        throw GeneratorError.invalidEmojiVersion
    }

    var currentGroup: String?
    var entries: [ParsedEmoji] = []
    var seen = Set<String>()

    for line in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
        if line.hasPrefix("# group: ") {
            currentGroup = String(line.dropFirst("# group: ".count))
            continue
        }
        guard line.contains("; fully-qualified") else { continue }
        guard let group = currentGroup, let mappedCategory = try category(for: group) else {
            continue
        }

        let halves = line.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
        guard halves.count == 2 else { throw GeneratorError.malformedEmojiLine(line) }
        let codePoints = halves[0].split(whereSeparator: \Character.isWhitespace)
        let scalars = try codePoints.map { token -> UnicodeScalar in
            guard let value = UInt32(token, radix: 16), let scalar = UnicodeScalar(value) else {
                throw GeneratorError.malformedEmojiLine(line)
            }
            return scalar
        }
        let sequence = String(String.UnicodeScalarView(scalars))

        guard let hash = halves[1].firstIndex(of: "#") else {
            throw GeneratorError.malformedEmojiLine(line)
        }
        let comment = halves[1][halves[1].index(after: hash)...]
            .trimmingCharacters(in: .whitespaces)
        let commentFields = comment.split(whereSeparator: \Character.isWhitespace)
        guard commentFields.count >= 3 else { throw GeneratorError.malformedEmojiLine(line) }
        let fallbackName = commentFields.dropFirst(2).joined(separator: " ")

        guard seen.insert(sequence).inserted else {
            throw GeneratorError.duplicateSequence(sequence)
        }
        entries.append(ParsedEmoji(
            sequence: sequence,
            category: mappedCategory,
            fallbackName: fallbackName
        ))
    }

    return entries
}

private func parseAnnotations(_ url: URL, rootKey: String) throws -> [String: CLDRAnnotation] {
    let data = try Data(contentsOf: url)
    guard
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let container = root[rootKey] as? [String: Any],
        let identity = container["identity"] as? [String: Any],
        let version = identity["version"] as? [String: Any],
        version["_cldrVersion"] as? String == cldrVersion,
        let rawAnnotations = container["annotations"] as? [String: Any]
    else {
        if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let container = root[rootKey] as? [String: Any],
           let identity = container["identity"] as? [String: Any],
           let version = identity["version"] as? [String: Any],
           version["_cldrVersion"] as? String != cldrVersion {
            throw GeneratorError.invalidCLDRVersion(url)
        }
        throw GeneratorError.malformedAnnotations(url)
    }

    var annotations: [String: CLDRAnnotation] = [:]
    for (sequence, rawValue) in rawAnnotations {
        guard let value = rawValue as? [String: Any] else { continue }
        let names = value["tts"] as? [String] ?? []
        let keywords = value["default"] as? [String] ?? []
        annotations[sequence] = CLDRAnnotation(name: names.first, keywords: keywords)
    }
    return annotations
}

private func withoutEmojiPresentationSelectors(_ sequence: String) -> String {
    String(sequence.unicodeScalars.filter { $0.value != 0xFE0F })
}

private func withoutSkinToneModifiers(_ sequence: String) -> String {
    String(sequence.unicodeScalars.filter { !(0x1F3FB...0x1F3FF).contains($0.value) })
}

private func hasSkinToneModifier(_ sequence: String) -> Bool {
    sequence.unicodeScalars.contains { (0x1F3FB...0x1F3FF).contains($0.value) }
}

private func resolveAnnotation(
    for entry: ParsedEmoji,
    primary: [String: CLDRAnnotation],
    derived: [String: CLDRAnnotation]
) -> CLDRAnnotation {
    if let exact = derived[entry.sequence] ?? primary[entry.sequence] {
        return exact
    }
    let normalized = withoutEmojiPresentationSelectors(entry.sequence)
    if let normalizedMatch = derived[normalized] ?? primary[normalized] {
        return normalizedMatch
    }
    return CLDRAnnotation(name: entry.fallbackName, keywords: [])
}

private func encoded<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(value)
    data.append(0x0A)
    return data
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func write(_ data: Data, named name: String, to directory: URL) throws {
    guard data.count <= resourceLimit else {
        throw GeneratorError.resourceTooLarge(name, data.count)
    }
    try data.write(to: directory.appendingPathComponent(name), options: .atomic)
}

private func run() throws {
    let arguments = try Arguments()
    let fileManager = FileManager.default
    try fileManager.createDirectory(
        at: arguments.outputDirectory,
        withIntermediateDirectories: true
    )

    let emojiTestData = try Data(contentsOf: arguments.emojiTest)
    let annotationData = try Data(contentsOf: arguments.annotations)
    let derivedAnnotationData = try Data(contentsOf: arguments.derivedAnnotations)
    let licenseData = try Data(contentsOf: arguments.license)
    let parsedEntries = try parseEmojiTest(emojiTestData)
    let primaryAnnotations = try parseAnnotations(arguments.annotations, rootKey: "annotations")
    let derivedAnnotations = try parseAnnotations(
        arguments.derivedAnnotations,
        rootKey: "annotationsDerived"
    )

    var browseEntries = parsedEntries.map {
        BrowseEntry(sequence: $0.sequence, category: $0.category, variantIndices: [])
    }
    let indexBySequence = Dictionary(
        uniqueKeysWithValues: browseEntries.enumerated().map { ($0.element.sequence, $0.offset) }
    )
    let indexByNormalizedSequence = Dictionary(
        uniqueKeysWithValues: browseEntries.enumerated().map {
            (withoutEmojiPresentationSelectors($0.element.sequence), $0.offset)
        }
    )
    var baseIndicesByName: [String: [Int]] = [:]
    for (index, entry) in parsedEntries.enumerated() where !hasSkinToneModifier(entry.sequence) {
        baseIndicesByName[entry.fallbackName, default: []].append(index)
    }
    for (variantIndex, entry) in parsedEntries.enumerated() where hasSkinToneModifier(entry.sequence) {
        let baseSequence = withoutSkinToneModifiers(entry.sequence)
        let baseName = entry.fallbackName.split(separator: ":", maxSplits: 1).first.map(String.init)
        let nameMatch = baseName.flatMap { name -> Int? in
            guard let matches = baseIndicesByName[name], matches.count == 1 else { return nil }
            return matches[0]
        }
        guard let baseIndex = indexBySequence[baseSequence]
            ?? indexByNormalizedSequence[withoutEmojiPresentationSelectors(baseSequence)]
            ?? nameMatch
        else {
            throw GeneratorError.missingBaseForVariant(entry.sequence)
        }
        browseEntries[baseIndex].variantIndices.append(variantIndex)
    }

    let searchAnnotations = parsedEntries.enumerated().map { index, entry in
        let annotation = resolveAnnotation(
            for: entry,
            primary: primaryAnnotations,
            derived: derivedAnnotations
        )
        return SearchAnnotation(
            catalogIndex: index,
            name: annotation.name ?? entry.fallbackName,
            keywords: annotation.keywords
        )
    }

    let browseData = try encoded(BrowsePayload(
        unicodeVersion: unicodeVersion,
        entries: browseEntries
    ))
    let searchData = try encoded(SearchPayload(
        cldrVersion: cldrVersion,
        locale: "en",
        annotations: searchAnnotations
    ))
    try write(browseData, named: "emoji_browse_v14.json", to: arguments.outputDirectory)
    try write(searchData, named: "emoji_search_en_cldr40.json", to: arguments.outputDirectory)
    try licenseData.write(
        to: arguments.outputDirectory.appendingPathComponent("emoji-unicode-license.txt"),
        options: .atomic
    )

    let provenance = """
    # Emoji resource provenance

    Generated by `tools/make_emoji_catalog.swift` from pinned Unicode inputs. Do not edit the
    JSON resources by hand.

    | Input | Version | Source | SHA-256 |
    |---|---|---|---|
    | `emoji-test.txt` | Emoji 14.0 | https://unicode.org/Public/emoji/14.0/emoji-test.txt | `\(sha256(emojiTestData))` |
    | `annotations.json` | CLDR 40 | https://raw.githubusercontent.com/unicode-org/cldr-json/40.0.0/cldr-json/cldr-annotations-full/annotations/en/annotations.json | `\(sha256(annotationData))` |
    | `annotations-derived.json` | CLDR 40 | https://raw.githubusercontent.com/unicode-org/cldr-json/40.0.0/cldr-json/cldr-annotations-derived-full/annotationsDerived/en/annotations.json | `\(sha256(derivedAnnotationData))` |
    | `license.txt` | Unicode License v3 | https://www.unicode.org/license.txt | `\(sha256(licenseData))` |

    Generation command from the repository root:

    ```bash
    env CLANG_MODULE_CACHE_PATH=/private/tmp/numpad-swift-module-cache \\
      SWIFT_MODULECACHE_PATH=/private/tmp/numpad-swift-module-cache \\
      swift tools/make_emoji_catalog.swift \\
      --emoji-test /private/tmp/numpad-emoji-inputs/emoji-test.txt \\
      --annotations /private/tmp/numpad-emoji-inputs/annotations.json \\
      --derived-annotations /private/tmp/numpad-emoji-inputs/annotations-derived.json \\
      --license /private/tmp/numpad-emoji-inputs/license.txt \\
      --output-dir Keyboard/Resources
    ```

    The generator retains only `fully-qualified` RGI entries, preserves Unicode's CLDR order,
    and records skin-tone families as catalog indices. Browse and English search resources are
    independently capped at 1,048,576 bytes.
    """ + "\n"
    try Data(provenance.utf8).write(
        to: arguments.outputDirectory.appendingPathComponent("EMOJI_PROVENANCE.md"),
        options: .atomic
    )

    print("entries: \(browseEntries.count)")
    print("browse bytes: \(browseData.count)")
    print("search bytes: \(searchData.count)")
}

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
