//
//  ContainerAppOpener.swift
//  NumPad / Keyboard
//
//  Shared (both targets). Opens the container app (`numpad://…`) from the keyboard extension by
//  walking the responder chain. Lives outside KeyboardViewController so the chain walk + success
//  reporting is unit-testable with a fake responder chain (no real app launch).
//

import UIKit

/// The seam the chain walk looks for. UIApplication conforms (below, after the fix); tests supply
/// a fake. The completion reports the system's `success` flag.
protocol ContainerURLOpening: AnyObject {
    func openContainerURL(_ url: URL, completion: @escaping (Bool) -> Void)
}

enum ContainerAppOpener {
    /// Walk `responder`'s chain and ask it to open `url`. `onOpened` runs only when the open
    /// succeeded — callers use it to count a store deep-link open.
    static func open(_ url: URL, from responder: UIResponder?, onOpened: @escaping () -> Void = {}) {
        // LEGACY (pre-fix) behavior, moved verbatim from KeyboardViewController.openContainerApp.
        let selector = NSSelectorFromString("openURL:")
        var current = responder
        while let candidate = current {
            if candidate.responds(to: selector) {
                candidate.perform(selector, with: url)
                onOpened()
                return
            }
            current = candidate.next
        }
    }
}
