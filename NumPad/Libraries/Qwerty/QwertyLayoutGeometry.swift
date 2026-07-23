import Foundation
import CoreGraphics
import UIKit

enum QwertyLayoutGeometry {
    struct RowFrames: Equatable {
        let frames: [CGRect]
    }

    static func contentWidth(bounds: CGRect, mode: QwertyLayoutMode, idiom: UIUserInterfaceIdiom) -> CGFloat {
        guard idiom == .pad else { return bounds.width }
        switch mode {
        case .automatic, .centered:
            return min(bounds.width, 720)
        case .compactLeft, .compactRight:
            return min(bounds.width, 420)
        case .split:
            return bounds.width
        }
    }

    static func contentOriginX(bounds: CGRect, mode: QwertyLayoutMode, idiom: UIUserInterfaceIdiom) -> CGFloat {
        let width = contentWidth(bounds: bounds, mode: mode, idiom: idiom)
        switch mode {
        case .compactLeft:
            return bounds.minX
        case .compactRight:
            return bounds.maxX - width
        case .automatic, .centered, .split:
            return bounds.midX - width / 2
        }
    }
}

enum NumpadGeometry {
    static let regularPadMaxWidth: CGFloat = 560

    static func contentFrame(bounds: CGRect, placement: NumpadPlacement, idiom: UIUserInterfaceIdiom) -> CGRect {
        guard idiom == .pad else { return bounds }
        let width = min(bounds.width, regularPadMaxWidth)
        switch placement {
        case .automatic, .center:
            return CGRect(x: bounds.midX - width / 2, y: bounds.minY, width: width, height: bounds.height)
        case .left:
            return CGRect(x: bounds.minX, y: bounds.minY, width: width, height: bounds.height)
        case .right:
            return CGRect(x: bounds.maxX - width, y: bounds.minY, width: width, height: bounds.height)
        case .fullWidth:
            return bounds
        }
    }
}

