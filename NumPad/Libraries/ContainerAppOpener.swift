//
//  ContainerAppOpener.swift
//  NumPad / Keyboard
//
//  Shared (both targets). Opens the container app (`numpad://…`) from the keyboard extension by
//  walking the responder chain. Lives outside KeyboardViewController so the chain walk + success
//  reporting is unit-testable with a fake responder chain (no real app launch).
//

import UIKit

/// The seam the chain walk looks for. UIApplication conforms (below); tests supply
/// a fake. The completion reports the system's `success` flag.
protocol ContainerURLOpening: AnyObject {
    func openContainerURL(_ url: URL, completion: @escaping (Bool) -> Void)
}

/// The real opener. `open(_:options:completionHandler:)` is NOT marked extension-unavailable in
/// the SDK (only `UIApplication.shared` is), so we call it directly on the UIApplication instance
/// found in the responder chain — no selector tricks, and the compiler checks the signature.
extension UIApplication: ContainerURLOpening {
    func openContainerURL(_ url: URL, completion: @escaping (Bool) -> Void) {
        open(url, options: [:]) { success in completion(success) }
    }
}

enum ContainerAppOpener {
    /// Walk `responder`'s chain to the first `ContainerURLOpening` (UIApplication in a keyboard
    /// extension) and open `url` with the modern async API. `onOpened` runs only when the system
    /// reports `success == true` — callers use it to count a store deep-link open.
    ///
    /// Why not the old approach: `extensionContext.open(_:)` does nothing for keyboards, and the
    /// legacy one-argument `openURL:` selector Apple documents as failing for apps built with the
    /// iOS 18 SDK on iOS 18+ — and it reported success unconditionally.
    static func open(_ url: URL, from responder: UIResponder?, onOpened: @escaping () -> Void = {}) {
        guard let opener = firstOpener(from: responder) else { return }
        opener.openContainerURL(url) { success in
            if success { onOpened() }
        }
    }

    static func firstOpener(from responder: UIResponder?) -> ContainerURLOpening? {
        var current = responder
        while let candidate = current {
            if let opener = candidate as? ContainerURLOpening { return opener }
            current = candidate.next
        }
        return nil
    }
}
