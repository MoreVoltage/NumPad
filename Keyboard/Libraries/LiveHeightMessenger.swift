// Shared messenger duplicated into the extension target to avoid cross-target imports
import Foundation
import CoreFoundation

struct LiveHeightMessage: Codable {
    let height: Double
    let isAdjusting: Bool
    let timestamp: TimeInterval
}

private var liveHeightHandlers: [UnsafeMutableRawPointer: (LiveHeightMessage) -> Void] = [:]

private func liveHeightCFCallback(_ center: CFNotificationCenter?, _ observer: UnsafeMutableRawPointer?, _ name: CFNotificationName?, _ object: UnsafeRawPointer?, _ userInfo: CFDictionary?) {
    guard let observer = observer, let handler = liveHeightHandlers[observer] else { return }
    guard let msg = LiveHeightMessenger.readLatest() else { return }
    DispatchQueue.main.async { handler(msg) }
}

final class LiveHeightMessenger {
    private init() {}
    private static let notificationName = "com.morevoltage.numpad.liveHeightChanged"

    private static func containerFileURL() -> URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.morevoltage.numpad.container") else { return nil }
        return container.appendingPathComponent("live_height.json", isDirectory: false)
    }

    static func observe(_ observer: AnyObject, handler: @escaping (LiveHeightMessage) -> Void) {
        let key = Unmanaged.passUnretained(observer).toOpaque()
        liveHeightHandlers[key] = handler
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), key, liveHeightCFCallback, notificationName as CFString, nil, .deliverImmediately)
    }

    static func remove(_ observer: AnyObject) {
        let key = Unmanaged.passUnretained(observer).toOpaque()
        liveHeightHandlers.removeValue(forKey: key)
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), key, CFNotificationName(notificationName as CFString), nil)
    }

    static func readLatest() -> LiveHeightMessage? {
        guard let url = containerFileURL(), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LiveHeightMessage.self, from: data)
    }
}


