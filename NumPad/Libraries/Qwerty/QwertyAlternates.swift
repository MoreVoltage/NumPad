import Foundation

struct QwertyAlternateCalloutLayout: Equatable {
    let itemWidth: CGFloat
    let totalWidth: CGFloat

    static let preferredItemWidth: CGFloat = 44
    static let horizontalInset: CGFloat = 2

    static func resolve(valueCount: Int, availableWidth: CGFloat) -> Self {
        guard valueCount > 0 else {
            return Self(itemWidth: 0, totalWidth: 0)
        }
        let usableWidth = max(0, availableWidth - horizontalInset * 2)
        let itemWidth = min(preferredItemWidth, usableWidth / CGFloat(valueCount))
        return Self(
            itemWidth: itemWidth,
            totalWidth: itemWidth * CGFloat(valueCount)
        )
    }
}

enum QwertyAlternates {
    private static let map: [String: [String]] = [
        "a": ["à", "á", "â", "ä", "æ", "ã", "å", "ā"],
        "c": ["ç", "ć", "č"],
        "e": ["è", "é", "ê", "ë", "ē", "ė", "ę"],
        "i": ["ì", "í", "î", "ï", "ī"],
        "n": ["ñ", "ń"],
        "o": ["ò", "ó", "ô", "ö", "õ", "ø", "ō", "œ"],
        "s": ["ß", "ś", "š"],
        "u": ["ù", "ú", "û", "ü", "ū"],
        "y": ["ÿ", "ý"],
        "'": ["‘", "’", "‛"],
        "\"": ["“", "”", "„", "«", "»"],
        "-": ["—", "–", "•"],
        "$": ["¢", "£", "€", "¥", "₩", "₽"],
        "£": ["$", "€", "¥"],
        "€": ["$", "£", "¥"]
    ]

    static func values(for key: String) -> [String] {
        let base = key.lowercased()
        return map[base] ?? []
    }

    static func values(for key: String, uppercase: Bool) -> [String] {
        let values = values(for: key)
        return uppercase ? values.map { $0.uppercased() } : values
    }
}

struct QwertyAlternateSelection {
    let values: [String]
    let itemWidth: CGFloat
    private(set) var highlightedValue: String?

    init(values: [String], itemWidth: CGFloat) {
        self.values = values
        self.itemWidth = itemWidth
    }

    @discardableResult
    mutating func update(horizontalLocation: CGFloat) -> String? {
        guard !values.isEmpty, itemWidth > 0 else {
            highlightedValue = nil
            return nil
        }
        let rawIndex = Int(floor(horizontalLocation / itemWidth))
        let index = min(max(rawIndex, 0), values.count - 1)
        highlightedValue = values[index]
        return highlightedValue
    }

    mutating func release() -> String? {
        defer { highlightedValue = nil }
        return highlightedValue
    }
}
