//
//  LockedTapResponse.swift
//  NumPad / Keyboard
//
//  Shared (both targets). What the keyboard does when the user taps something locked behind the
//  paywall (a locked key, a locked pack in the pack picker, a locked conversion category).
//
//  App Review guideline 4.4.1: keyboard extensions may not launch other apps besides Settings.
//  So a locked tap never opens NumPad. It counts the tap for the lock funnel and shows a short,
//  non-blocking hint telling the user where to unlock it. `storeDeeplinkOpens` is never bumped
//  here, because no deep link is attempted. It also leaves a `StoreHandoff` record, so opening
//  the app soon after lands on the Store once.
//

import Foundation
import CoreGraphics

/// Where a locked tap came from. The extension logs no analytics; the source only travels to the
/// app in the `StoreHandoff` record, as the Store's funnel `source`.
enum LockedTapSource: CaseIterable {
    case keyLock
    case packPicker
    case conversionLock
}

/// Implemented by the keyboard view controller.
protocol LockedTapHintPresenting: AnyObject {
    /// Show the transient "unlock in the app" hint.
    func showLockedTapHint(_ message: String)
    /// Close whichever overlay (pack picker, converter) produced the locked selection.
    func dismissOverlaysForLockedTap()
}

enum LockedTapResponse {
    /// How long the hint stays up before fading. Short so it never blocks typing.
    static let hintDisplayDuration: TimeInterval = 2.5

    /// Where locked taps leave their Store handoff record. Swapped only by tests.
    static var handoffStore = StoreHandoffStore.shared

    static var hintMessage: String {
        NSLocalizedString("Open the NumPad app to unlock this.",
                          comment: "Keyboard: brief hint shown after tapping a locked key, pack or conversion")
    }

    /// Entry point for `KeyboardViewController.tapped(_:)`. Returns `true` when the key is locked
    /// and the tap was consumed; the caller must return without performing any key action.
    static func handleKeyTap(isLocked: Bool, pack: KeyboardType? = nil, presenter: LockedTapHintPresenting) -> Bool {
        guard isLocked else { return false }
        handle(source: .keyLock, pack: pack, presenter: presenter)
        return true
    }

    /// Entry point for a locked pack (pack picker) or locked conversion category. The overlay is
    /// closed first, so the hint is never drawn underneath it.
    static func handleLockedOverlaySelection(source: LockedTapSource, pack: KeyboardType? = nil,
                                             presenter: LockedTapHintPresenting) {
        presenter.dismissOverlaysForLockedTap()
        handle(source: source, pack: pack, presenter: presenter)
    }

    private static func handle(source: LockedTapSource, pack: KeyboardType?, presenter: LockedTapHintPresenting) {
        LockFunnelCounters.incrementLockedKeyTaps()
        handoffStore.record(source: source, pack: pack)
        presenter.showLockedTapHint(hintMessage)
    }
}

// MARK: - Hint lifetime

protocol LockedTapHintCancellable: AnyObject {
    func cancel()
}

extension DispatchWorkItem: LockedTapHintCancellable {}

/// Injectable clock so the hint's timing can be tested deterministically.
protocol LockedTapHintScheduling {
    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) -> LockedTapHintCancellable
}

struct MainQueueLockedTapHintScheduler: LockedTapHintScheduling {
    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) -> LockedTapHintCancellable {
        let work = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        return work
    }
}

/// The view work, implemented by the keyboard view controller.
protocol LockedTapHintSurface: AnyObject {
    /// Hide both chips, show the pill with `message`, announce it.
    func lockedTapHintShow(_ message: String)
    /// Start fading the pill out. Call `completion` when the fade ends (synchronously under
    /// Reduce Motion). The completion may arrive after a newer hint has been presented.
    func lockedTapHintFadeOut(completion: @escaping () -> Void)
    /// Hide the pill and recompute both chips from the current document context.
    func lockedTapHintDidHide()
}

/// Owns the hint's lifetime. Each presentation gets a generation number; only the current one
/// may fade the pill, hide it and restore the chips. So a tap during the 0.2 s fade-out keeps its
/// new hint, and a tap just before the deadline restarts the full duration.
final class LockedTapHintCoordinator {
    weak var surface: LockedTapHintSurface?
    private let scheduler: LockedTapHintScheduling
    private let duration: TimeInterval
    private var pendingExpiry: LockedTapHintCancellable?
    private var generation = 0
    private(set) var isVisible = false

    /// The math-preview and What's New chips may show only when no hint is up (including its
    /// fade-out). The hint passes touches through, so a chip under it would take the tap.
    var allowsChips: Bool { !isVisible }

    init(scheduler: LockedTapHintScheduling = MainQueueLockedTapHintScheduler(),
         duration: TimeInterval = LockedTapResponse.hintDisplayDuration) {
        self.scheduler = scheduler
        self.duration = duration
    }

    func present(_ message: String) {
        generation &+= 1
        let token = generation
        isVisible = true
        pendingExpiry?.cancel()
        surface?.lockedTapHintShow(message)
        pendingExpiry = scheduler.schedule(after: duration) { [weak self] in self?.expire(token) }
    }

    private func expire(_ token: Int) {
        guard token == generation, isVisible else { return }
        pendingExpiry = nil
        surface?.lockedTapHintFadeOut { [weak self] in self?.finishHide(token) }
    }

    private func finishHide(_ token: Int) {
        // A newer tap superseded this presentation while it was fading: leave its hint alone.
        guard token == generation, isVisible else { return }
        isVisible = false
        surface?.lockedTapHintDidHide()
    }
}

// MARK: - Hint layout

/// Size rules for the hint pill: up to two lines, height capped from the current font so longer
/// translations and larger text wrap instead of truncating, narrow and centered.
enum LockedTapHintLayout {
    static let maxLines = 2
    static let minHeight: CGFloat = 28
    static let verticalPadding: CGFloat = 5
    static let horizontalPadding: CGFloat = 12
    static let maxWidth: CGFloat = 300
    static let topInset: CGFloat = 6
    static let edgeInset: CGFloat = 8

    static func maxHeight(lineHeight: CGFloat) -> CGFloat {
        CGFloat(maxLines) * lineHeight + 2 * verticalPadding
    }
}
