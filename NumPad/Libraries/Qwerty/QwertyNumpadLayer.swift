import Foundation

/// The one-tap numpad-flip canvas (plan §2): a digits grid + bottom row rendered by the same
/// `QwertyKeyboardView`, replacing the QWERTY letter rows while the top strip (with the flip
/// key) stays put. This removes the globe round-trip for numeric entry mid-typing — the
/// numpad extension remains the deep numeric experience (packs, overlays, themes).
enum QwertyNumpadLayer {

    static func rows(needsSwitchKey: Bool, needsDismissKey: Bool = false) -> [QwertyRow] {
        let third = QwertyLayout.rowUnitWidth / 3
        let digitRows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]].map { digits in
            QwertyRow(keys: digits.map {
                QwertyKey(kind: .character($0, shifted: $0), width: third)
            })
        }
        return digitRows + [bottomRow(needsSwitchKey: needsSwitchKey,
                                      needsDismissKey: needsDismissKey)]
    }

    private static func bottomRow(needsSwitchKey: Bool, needsDismissKey: Bool) -> QwertyRow {
        var keys: [QwertyKey]
        switch (needsSwitchKey, needsDismissKey) {
        case (true, false):
            keys = [QwertyKey(kind: .globe, width: 1.5),
                    QwertyKey(kind: .character("0", shifted: "0"), width: 2.5),
                    QwertyKey(kind: .character(".", shifted: "."), width: 2.0),
                    QwertyKey(kind: .backspace, width: 2.0),
                    QwertyKey(kind: .ret, width: 2.0)]
        case (false, false):
            keys = [QwertyKey(kind: .character("0", shifted: "0"), width: 4.0),
                    QwertyKey(kind: .character(".", shifted: "."), width: 2.0),
                    QwertyKey(kind: .backspace, width: 2.0),
                    QwertyKey(kind: .ret, width: 2.0)]
        case (true, true):
            keys = [QwertyKey(kind: .globe, width: 1.5),
                    QwertyKey(kind: .character("0", shifted: "0"), width: 2.0),
                    QwertyKey(kind: .character(".", shifted: "."), width: 1.5),
                    QwertyKey(kind: .backspace, width: 1.5),
                    QwertyKey(kind: .ret, width: 2.0),
                    QwertyKey(kind: .dismissKeyboard, width: 1.5)]
        case (false, true):
            keys = [QwertyKey(kind: .character("0", shifted: "0"), width: 3.0),
                    QwertyKey(kind: .character(".", shifted: "."), width: 1.5),
                    QwertyKey(kind: .backspace, width: 1.5),
                    QwertyKey(kind: .ret, width: 2.5),
                    QwertyKey(kind: .dismissKeyboard, width: 1.5)]
        }
        return QwertyRow(keys: keys)
    }
}
