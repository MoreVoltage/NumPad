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
        let numpadWidthSize: NumpadWidthSize
        let heightPreset: KeyboardHeightPreset

        init(
            bounds: CGRect,
            safeAreaInsets: UIEdgeInsets,
            horizontalSizeClass: UIUserInterfaceSizeClass,
            numpadWidthSize: NumpadWidthSize,
            heightPreset: KeyboardHeightPreset
        ) {
            self.bounds = bounds
            self.safeAreaInsets = safeAreaInsets
            self.horizontalSizeClass = horizontalSizeClass
            self.numpadWidthSize = numpadWidthSize
            self.heightPreset = heightPreset
        }
    }

    let upperPresentation: UpperPresentation
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
    static let upperContentClearance: CGFloat = 24
    /// The compact selector's 44pt touch target plus its 8pt top and destination gaps. This is
    /// deliberately separate from the navigation allowance so this number continues to describe
    /// only workspace-owned chrome.
    static let compactChromeHeight: CGFloat = 60
    /// `contentNavigation` is embedded above the dock. Its 44pt navigation bar plus UIKit's
    /// observed 20pt compact containment/spacing footprint consumes 64pt before destination
    /// content can be seen. Keeping the extra allowance explicit prevents a nominal 44pt bar
    /// from silently reducing the real viewport below its contract.
    static let navigationBarAllowance: CGFloat = 64
    /// A short window must still leave a meaningful, usable piece of the destination below its
    /// navigation bar; less than this makes the destination appear present but unusable.
    static let meaningfulDestinationViewportHeight: CGFloat = 72
    /// The explicit short-window reserve: compact selector/chrome + embedded navigation bar +
    /// a 72pt usable destination viewport. The requested height preset is retained and its dock
    /// height is restored as soon as the safe height can accommodate this full reserve.
    static let minimumUpperWorkspaceHeight: CGFloat = compactChromeHeight
        + navigationBarAllowance
        + meaningfulDestinationViewportHeight

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

        let requestedDockHeight = max(160, input.heightPreset.baseHeight(idiom: .pad) * 0.55 + 24)
        let availableDockHeight = max(0, safeHeight - minimumUpperWorkspaceHeight)
        let dockHeight = min(requestedDockHeight, availableDockHeight)
        let safeMinX = input.bounds.minX + input.safeAreaInsets.left
        let safeBounds = CGRect(
            x: safeMinX,
            y: input.bounds.minY + input.safeAreaInsets.top,
            width: safeWidth,
            height: safeHeight
        )
        let numpadLayout = NumpadGeometry.resolve(
            width: input.numpadWidthSize,
            bounds: safeBounds,
            idiom: .pad,
            horizontalSizeClass: input.horizontalSizeClass,
            isFloating: false
        )
        let dockMaxY = input.bounds.maxY - input.safeAreaInsets.bottom
        let dockFrame = CGRect(
            x: numpadLayout.contentFrame.minX,
            y: max(input.bounds.minY + input.safeAreaInsets.top, dockMaxY - dockHeight),
            width: numpadLayout.contentFrame.width,
            height: dockHeight
        )

        return IPadStudioLayout(
            upperPresentation: upperPresentation,
            showsUtilityRails: !isCompact
                && safeWidth >= centeredPreviewMinimumWidth
                && numpadLayout.contentFrame.width < safeWidth,
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
