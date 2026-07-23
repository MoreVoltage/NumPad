import Foundation

struct QwertyPersonalizationContext: Codable, Hashable, Equatable {
    enum DeviceClass: String, Codable { case phone, pad }
    let deviceClass: DeviceClass
    let layoutMode: QwertyLayoutMode

    static var phoneAutomatic: QwertyPersonalizationContext {
        QwertyPersonalizationContext(deviceClass: .phone, layoutMode: .automatic)
    }
}

