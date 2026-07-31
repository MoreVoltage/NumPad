import Foundation
import UIKit

struct QwertyPersonalizationContext: Codable, Hashable, Equatable {
    enum DeviceClass: String, Codable { case phone, pad }
    enum Layout: String, Codable {
        // Legacy keys remain decodable and inspectable, but no new composition resolves to one.
        case automatic, centered, split, compactLeft, compactRight
        case standard
        case fullLeft = "full-left"
        case fullRight = "full-right"
    }

    let deviceClass: DeviceClass
    let layoutMode: Layout

    static var phoneAutomatic: QwertyPersonalizationContext {
        QwertyPersonalizationContext(deviceClass: .phone, layoutMode: .automatic)
    }

    static func resolved(idiom: UIUserInterfaceIdiom,
                         layout: IPadQwertyLayout,
                         numpadSide: FullKeyboardNumpadSide) -> QwertyPersonalizationContext {
        resolvedLayout(idiom: idiom, layout: layout, numpadSide: numpadSide)
    }

    /// Resolves from the exact same composition inputs as the keyboard panes. A Full preference
    /// that falls back to Standard (compact, narrow, floating, or phone) must never keep using a
    /// Full-left/right learned-offset store.
    static func resolved(bounds: CGRect,
                         idiom: UIUserInterfaceIdiom,
                         horizontalSizeClass: UIUserInterfaceSizeClass?,
                         layout: IPadQwertyLayout,
                         numpadSide: FullKeyboardNumpadSide,
                         isFloating: Bool) -> QwertyPersonalizationContext {
        let composition = IPadKeyboardCompositionGeometry.resolve(
            bounds: bounds,
            idiom: idiom,
            horizontalSizeClass: horizontalSizeClass,
            layout: layout,
            numpadSide: numpadSide,
            isFloating: isFloating
        )
        guard composition.numpadFrame != nil else {
            return idiom == .pad
                ? QwertyPersonalizationContext(deviceClass: .pad, layoutMode: .standard)
                : .phoneAutomatic
        }
        return resolvedLayout(idiom: idiom, layout: layout, numpadSide: numpadSide)
    }

    private static func resolvedLayout(idiom: UIUserInterfaceIdiom,
                                       layout: IPadQwertyLayout,
                                       numpadSide: FullKeyboardNumpadSide) -> QwertyPersonalizationContext {
        guard idiom == .pad else { return .phoneAutomatic }
        let resolvedLayout: Layout
        switch layout {
        case .standard:
            resolvedLayout = .standard
        case .full:
            resolvedLayout = numpadSide == .left ? .fullLeft : .fullRight
        }
        return QwertyPersonalizationContext(
            deviceClass: .pad,
            layoutMode: resolvedLayout
        )
    }

    var storageKey: String {
        "\(deviceClass.rawValue)/\(layoutMode.rawValue)"
    }
}
