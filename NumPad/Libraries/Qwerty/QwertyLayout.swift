import Foundation

/// Options that shape the QWERTY layout.
struct QwertyLayoutOptions: Equatable {
    /// Owner decision §0.2: period + comma on the letters layer — one switch, both together,
    /// default ON. They flank the space bar on the bottom row (the Android-convention denser
    /// bottom row) rather than squeezing into the shift row, so letter rows 1–3 keep exact
    /// system geometry and the single deliberate parity divergence stays isolated to the
    /// bottom row (plan §0.1 / risk #10).
    var periodCommaOnLetters = true
    /// Mirrors `UIInputViewController.needsInputModeSwitchKey` — the globe key is drawn only
    /// when the system says this keyboard must provide one.
    var needsSwitchKey = true
}

/// Pure, deterministic QWERTY layout builder — the geometry source of truth for the parity
/// spec (plan §0.1). Widths are in layout units where a letter key is 1.0 and every row spans
/// `rowUnitWidth`; the renderer multiplies by (canvas width / rowUnitWidth).
enum QwertyLayout {
    /// Every row spans exactly this many units — the system keyboard's 10-key top row.
    static let rowUnitWidth: Double = 10.0

    static func rows(layer: QwertyLayer, options: QwertyLayoutOptions) -> [QwertyRow] {
        switch layer {
        case .letters:
            return lettersRows(options: options)
        case .symbols:
            return symbolRows(top: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
                              middle: ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
                              toggle: .extendedSymbols,
                              options: options)
        case .extendedSymbols:
            return symbolRows(top: ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
                              middle: ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"],
                              toggle: .symbols,
                              options: options)
        }
    }

    // MARK: - Letters layer

    private static func lettersRows(options: QwertyLayoutOptions) -> [QwertyRow] {
        [
            QwertyRow(keys: characterKeys(["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"])),
            QwertyRow(keys: characterKeys(["a", "s", "d", "f", "g", "h", "j", "k", "l"]),
                      leadingMargin: 0.5, trailingMargin: 0.5),
            QwertyRow(keys: [QwertyKey(kind: .shift, width: 1.5)]
                          + characterKeys(["z", "x", "c", "v", "b", "n", "m"])
                          + [QwertyKey(kind: .backspace, width: 1.5)]),
            lettersBottomRow(options: options),
        ]
    }

    /// The bottom row is the only place the period/comma switch changes anything. Widths are
    /// the documented parity divergence: with the switch ON, space narrows and return gives up
    /// half a unit to absorb the two 1.0-unit punctuation keys; with it OFF the row is
    /// unit-identical to the system keyboard.
    private static func lettersBottomRow(options: QwertyLayoutOptions) -> QwertyRow {
        var keys: [QwertyKey] = []
        if options.periodCommaOnLetters {
            if options.needsSwitchKey {
                keys = [QwertyKey(kind: .layerSwitch(.symbols), width: 1.25),
                        QwertyKey(kind: .globe, width: 1.25),
                        characterKey(","),
                        QwertyKey(kind: .space, width: 3.5),
                        characterKey("."),
                        QwertyKey(kind: .ret, width: 2.0)]
            } else {
                keys = [QwertyKey(kind: .layerSwitch(.symbols), width: 1.5),
                        characterKey(","),
                        QwertyKey(kind: .space, width: 4.5),
                        characterKey("."),
                        QwertyKey(kind: .ret, width: 2.0)]
            }
        } else {
            keys = systemBottomRow(abcOrSymbols: .layerSwitch(.symbols),
                                   needsSwitchKey: options.needsSwitchKey)
        }
        return QwertyRow(keys: keys)
    }

    // MARK: - Symbol layers

    private static func symbolRows(top: [String],
                                   middle: [String],
                                   toggle: QwertyLayer,
                                   options: QwertyLayoutOptions) -> [QwertyRow] {
        let punctuation = [".", ",", "?", "!", "'"].map { characterKey($0, width: 1.4) }
        return [
            QwertyRow(keys: characterKeys(top)),
            QwertyRow(keys: characterKeys(middle)),
            QwertyRow(keys: [QwertyKey(kind: .layerSwitch(toggle), width: 1.5)]
                          + punctuation
                          + [QwertyKey(kind: .backspace, width: 1.5)]),
            QwertyRow(keys: systemBottomRow(abcOrSymbols: .layerSwitch(.letters),
                                            needsSwitchKey: options.needsSwitchKey)),
        ]
    }

    /// The system keyboard's bottom row geometry, shared by the symbol layers and the
    /// letters layer when the period/comma switch is OFF.
    private static func systemBottomRow(abcOrSymbols: QwertyKeyKind,
                                        needsSwitchKey: Bool) -> [QwertyKey] {
        if needsSwitchKey {
            return [QwertyKey(kind: abcOrSymbols, width: 1.25),
                    QwertyKey(kind: .globe, width: 1.25),
                    QwertyKey(kind: .space, width: 5.0),
                    QwertyKey(kind: .ret, width: 2.5)]
        }
        return [QwertyKey(kind: abcOrSymbols, width: 2.5),
                QwertyKey(kind: .space, width: 5.0),
                QwertyKey(kind: .ret, width: 2.5)]
    }

    // MARK: - Helpers

    private static func characterKeys(_ strings: [String]) -> [QwertyKey] {
        strings.map { characterKey($0) }
    }

    private static func characterKey(_ string: String, width: Double = 1.0) -> QwertyKey {
        QwertyKey(kind: .character(string, shifted: string.uppercased()), width: width)
    }
}

/// The strip above the letter rows: the numpad-flip key plus either the persistent number row
/// or the active pack's keys — the swappable number line (owner decision §0.3).
enum QwertyTopStrip: Equatable {
    case numbers
    case pack([String])

    static func keys(for strip: QwertyTopStrip) -> [QwertyKey] {
        let flip = QwertyKey(kind: .numpadFlip, width: 1.0)
        let contents: [String]
        switch strip {
        case .numbers:
            contents = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
        case .pack(let keys):
            contents = keys
        }
        guard !contents.isEmpty else {
            return [QwertyKey(kind: .numpadFlip, width: QwertyLayout.rowUnitWidth)]
        }
        let width = (QwertyLayout.rowUnitWidth - flip.width) / Double(contents.count)
        return [flip] + contents.map {
            QwertyKey(kind: .character($0, shifted: $0.uppercased()), width: width)
        }
    }
}
