import XCTest
@testable import NumPad

final class QwertyLayoutGeometryTests: XCTestCase {
    func test_centeredCapsWidthOnPad() {
        let bounds = CGRect(x: 0, y: 0, width: 1024, height: 300)
        let width = QwertyLayoutGeometry.contentWidth(bounds: bounds, mode: .centered, idiom: .pad)
        XCTAssertLessThanOrEqual(width, 720)
        let origin = QwertyLayoutGeometry.contentOriginX(bounds: bounds, mode: .centered, idiom: .pad)
        XCTAssertEqual(origin, (1024 - width) / 2, accuracy: 0.5)
    }

    func test_numpadPlacement() {
        let bounds = CGRect(x: 0, y: 0, width: 1024, height: 350)
        let center = NumpadGeometry.contentFrame(bounds: bounds, placement: .center, idiom: .pad)
        XCTAssertLessThanOrEqual(center.width, NumpadGeometry.regularPadMaxWidth)
        let full = NumpadGeometry.contentFrame(bounds: bounds, placement: .fullWidth, idiom: .pad)
        XCTAssertEqual(full, bounds)
    }
}

