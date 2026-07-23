import Foundation
import CoreGraphics

struct QwertyCursorAccumulator {
    var stepWidth: CGFloat = 12
    var deadBand: CGFloat = 4
    private var carry: CGFloat = 0

    mutating func consume(translation: CGFloat) -> Int {
        let adjusted = translation
        if abs(carry + adjusted) < deadBand, abs(carry) < deadBand {
            carry += adjusted
            return 0
        }
        carry += adjusted
        let steps = Int(carry / stepWidth)
        carry -= CGFloat(steps) * stepWidth
        return steps
    }

    mutating func reset() {
        carry = 0
    }
}

