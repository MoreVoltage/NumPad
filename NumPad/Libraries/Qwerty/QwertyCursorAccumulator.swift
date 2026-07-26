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

struct QwertySpaceCursorInteraction {
    enum State: Equatable {
        case idle
        case pressing
        case tracking
    }

    enum Completion: Equatable {
        case insertSpace
        case cursorMoved
    }

    static let holdDuration: TimeInterval = 0.35

    private(set) var state: State = .idle
    private var beganAt: TimeInterval?
    private var accumulator = QwertyCursorAccumulator()

    mutating func begin(at time: TimeInterval) {
        beganAt = time
        accumulator.reset()
        state = .pressing
    }

    @discardableResult
    mutating func activateTracking(at time: TimeInterval) -> Bool {
        guard state == .pressing,
              let beganAt else { return false }
        let elapsed = time - beganAt
        guard elapsed >= Self.holdDuration
                || abs(elapsed - Self.holdDuration) < 0.000_001 else { return false }
        state = .tracking
        accumulator.reset()
        return true
    }

    mutating func move(translation: CGFloat, at time: TimeInterval) -> Int {
        if state == .pressing {
            guard activateTracking(at: time) else { return 0 }
        }
        guard state == .tracking else { return 0 }
        return accumulator.consume(translation: translation)
    }

    mutating func end() -> Completion {
        let completion: Completion = state == .tracking ? .cursorMoved : .insertSpace
        reset()
        return completion
    }

    mutating func cancel() {
        reset()
    }

    private mutating func reset() {
        beganAt = nil
        accumulator.reset()
        state = .idle
    }
}
