import Foundation
import UIKit

struct QwertyPersonalizationContext: Codable, Hashable, Equatable {
    enum DeviceClass: String, Codable { case phone, pad }
    let deviceClass: DeviceClass
    let layoutMode: QwertyLayoutMode

    static var phoneAutomatic: QwertyPersonalizationContext {
        QwertyPersonalizationContext(deviceClass: .phone, layoutMode: .automatic)
    }

    static func resolved(idiom: UIUserInterfaceIdiom,
                         layoutMode: QwertyLayoutMode) -> QwertyPersonalizationContext {
        QwertyPersonalizationContext(
            deviceClass: idiom == .pad ? .pad : .phone,
            layoutMode: idiom == .pad ? layoutMode : .automatic
        )
    }

    var storageKey: String {
        "\(deviceClass.rawValue)/\(layoutMode.rawValue)"
    }
}
