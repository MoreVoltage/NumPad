//
//  IPadStudioLayout.swift
//  NumPad
//

import UIKit

/// The pure geometry contract for the iPad Studio workspace.  Keeping this separate from the
/// controller makes rotation, split-view resizing, and keyboard placement decisions deterministic
/// and ensures the permanent dock never becomes scroll content by accident.
struct IPadStudioLayout: Equatable {
    enum UpperPresentation: Equatable {
        case canvasAndInspector
        case singleColumn
        case compactPhoneShell
    }

    struct Input: Equatable {
        let bounds: CGRect
        let safeAreaInsets: UIEdgeInsets
        let horizontalSizeClass: UIUserInterfaceSizeClass
        let placement: NumpadPlacement
        let heightPreset: KeyboardHeightPreset

        init(
            bounds: CGRect,
            safeAreaInsets: UIEdgeInsets,
            horizontalSizeClass: UIUserInterfaceSizeClass,
            placement: NumpadPlacement,
            heightPreset: KeyboardHeightPreset
        ) {
            self.bounds = bounds
            self.safeAreaInsets = safeAreaInsets
            self.horizontalSizeClass = horizontalSizeClass
            self.placement = placement
            self.heightPreset = heightPreset
        }
    }

    let upperPresentation: UpperPresentation
    let resolvedPlacement: NumpadPlacement
    let showsUtilityRails: Bool
    let dockFrame: CGRect
    let dockHeight: CGFloat
    let upperContentBottomInset: CGFloat

    /// These are intentionally data rather than controller implementation details: tests can
    /// protect the safety invariant even when UIKit's containment layout changes.
    let dockIsStructuralSibling: Bool
    let dockPinsToSafeAreaBottom: Bool

    static let landscapeWorkspaceMinimumWidth: CGFloat = 900
    static let centeredPreviewMinimumWidth: CGFloat = 700
    static let maximumPreviewWidth: CGFloat = 560
    static let upperContentClearance: CGFloat = 24
    /// Keeps compact chrome usable in a short Split View window: a 44pt selector, 8pt top/gap
    /// margins, and a 72pt meaningful destination viewport. The selected keyboard-height preset
    /// remains unchanged; this only caps the safe visual dock until space returns.
    static let minimumUpperWorkspaceHeight: CGFloat = 132

    static func resolve(_ input: Input) -> IPadStudioLayout {
        let safeWidth = max(0, input.bounds.width - input.safeAreaInsets.left - input.safeAreaInsets.right)
        let safeHeight = max(0, input.bounds.height - input.safeAreaInsets.top - input.safeAreaInsets.bottom)
        let isCompact = input.horizontalSizeClass == .compact || safeWidth < 500
        let isLandscapeWorkspace = !isCompact
            && input.bounds.width > input.bounds.height
            && safeWidth >= landscapeWorkspaceMinimumWidth
        let upperPresentation: UpperPresentation = isCompact
            ? .compactPhoneShell
            : (isLandscapeWorkspace ? .canvasAndInspector : .singleColumn)

        let canUseRails = !isCompact && safeWidth >= centeredPreviewMinimumWidth
        let resolvedPlacement: NumpadPlacement
        if !canUseRails {
            // A side/centered preview must never overflow a narrow split pane.  Full-width is the
            // truthful preview fallback and is deliberately not a floating keyboard.
            resolvedPlacement = .fullWidth
        } else {
            switch input.placement {
            case .automatic: resolvedPlacement = .center
            case .center, .left, .right: resolvedPlacement = input.placement
            case .fullWidth: resolvedPlacement = .fullWidth
            }
        }

        let requestedDockHeight = max(160, input.heightPreset.baseHeight(idiom: .pad) * 0.55 + 24)
        let availableDockHeight = max(0, safeHeight - minimumUpperWorkspaceHeight)
        let dockHeight = min(requestedDockHeight, availableDockHeight)
        let dockWidth = resolvedPlacement == .fullWidth
            ? safeWidth
            : min(maximumPreviewWidth, safeWidth)
        let safeMinX = input.bounds.minX + input.safeAreaInsets.left
        let dockX: CGFloat
        switch resolvedPlacement {
        case .left: dockX = safeMinX
        case .right: dockX = safeMinX + safeWidth - dockWidth
        case .automatic, .center, .fullWidth: dockX = safeMinX + (safeWidth - dockWidth) / 2
        }
        let dockMaxY = input.bounds.maxY - input.safeAreaInsets.bottom
        let dockFrame = CGRect(
            x: dockX,
            y: max(input.bounds.minY + input.safeAreaInsets.top, dockMaxY - dockHeight),
            width: dockWidth,
            height: dockHeight
        )

        return IPadStudioLayout(
            upperPresentation: upperPresentation,
            resolvedPlacement: resolvedPlacement,
            showsUtilityRails: canUseRails && resolvedPlacement != .fullWidth,
            dockFrame: dockFrame,
            dockHeight: dockFrame.height,
            // The scroll view itself ends at the dock's top edge. Only retain a small clearance
            // so the final row does not sit flush against that permanent sibling.
            upperContentBottomInset: upperContentClearance,
            dockIsStructuralSibling: true,
            dockPinsToSafeAreaBottom: true
        )
    }
}
