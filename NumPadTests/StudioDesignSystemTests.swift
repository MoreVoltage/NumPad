//
//  StudioDesignSystemTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class StudioDesignSystemTests: XCTestCase {
    func test_lockedControlsRemainActionableAndExplainPro() {
        var rowTapCount = 0
        let row = StudioRowView(
            title: "Custom keys",
            accessory: .locked("Pro")
        )
        row.onTap = { rowTapCount += 1 }

        var tileTapCount = 0
        let tile = StudioTileView(title: "Kiosk", lockText: "Pro")
        tile.onTap = { tileTapCount += 1 }

        row.sendActions(for: .touchUpInside)
        tile.sendActions(for: .touchUpInside)

        XCTAssertEqual(rowTapCount, 1, "Removing the Pro action from a locked row must fail this test.")
        XCTAssertEqual(tileTapCount, 1, "Removing the Pro action from a locked tile must fail this test.")
        XCTAssertFalse(row.accessibilityTraits.contains(.notEnabled), "Marking a locked Pro row unavailable hides its purchase action from VoiceOver.")
        XCTAssertFalse(tile.accessibilityTraits.contains(.notEnabled), "Marking a locked Pro tile unavailable hides its purchase action from VoiceOver.")
        XCTAssertEqual(row.accessibilityHint, NSLocalizedString("Unlock with NumPad Pro", comment: ""), "Removing the explicit localized Pro action from a locked row must fail this test.")
        XCTAssertEqual(tile.accessibilityHint, NSLocalizedString("Unlock with NumPad Pro", comment: ""), "Removing the explicit localized Pro action from a locked tile must fail this test.")
    }

    func test_replacingTileLockTextDoesNotAccumulateArrangedWrappers() throws {
        let tile = StudioTileView(title: "Kiosk", lockText: "Pro")

        tile.lockText = "Premium"
        tile.lockText = "Pro"
        tile.lockText = "Premium"
        tile.lockText = "Pro"

        let contentStack = try XCTUnwrap(tile.subviews.first as? UIStackView)
        XCTAssertEqual(contentStack.arrangedSubviews.count, 2, "Leaving previous lock wrappers arranged makes a tile grow every time its Pro label changes.")
    }

    func test_segmentedControlClampsAnInvalidInitialSelection() {
        let control = StudioSegmentedControl(
            titles: ["Compact", "Regular", "Tall"],
            selectedIndex: 99
        )

        XCTAssertEqual(
            control.selectedIndex,
            2,
            "Keeping an invalid initial selection leaves every segment unselected."
        )
    }

    func test_statusHeroNamesEveryReadinessStateToVoiceOver() {
        let cases: [(StudioStatusLevel, String)] = [
            (.ok, "Ready"),
            (.warn, "Needs attention"),
            (.unavailable, "Unavailable")
        ]

        for (level, expectedState) in cases {
            let hero = StudioStatusHeroView(
                level: level,
                title: "Keyboard",
                message: "Review your setup"
            )

            XCTAssertTrue(
                hero.accessibilityLabel?.contains(expectedState) == true,
                "Removing the \(expectedState) state name makes VoiceOver rely on color or a generic title."
            )
        }
    }

    func test_statusHeroActionUsesCallerIdentifierOnlyWhileVisible() {
        let hero = StudioStatusHeroView(
            level: .warn,
            title: "Finish setup",
            actionTitle: "Open setup"
        )

        hero.actionAccessibilityIdentifier = "studio.keyboard.openSetup"

        XCTAssertEqual(hero.actionAccessibilityIdentifier, "studio.keyboard.openSetup")
        XCTAssertTrue(
            accessibilityIdentifiers(in: hero).contains("studio.keyboard.openSetup"),
            "Removing the caller identifier makes the visible hero action unreachable to stable UI automation."
        )

        hero.setActionTitle(nil)

        XCTAssertFalse(
            accessibilityIdentifiers(in: hero).contains("studio.keyboard.openSetup"),
            "Leaving a removed hero action in the accessibility tree creates a stale actionable artifact."
        )
    }

    func test_paletteTextAndFilledActionRolesKeepReadableContrast() throws {
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        for palette in [StudioPalette.standard, .advanced, .onboarding] {
            for traits in [light, dark] {
                XCTAssertGreaterThanOrEqual(
                    contrastRatio(palette.textPrimary, palette.surface, traits: traits),
                    4.5,
                    "Weakening the primary text role against its surface makes ordinary Studio copy unreadable."
                )
                XCTAssertGreaterThanOrEqual(
                    contrastRatio(palette.textSecondary, palette.surface, traits: traits),
                    4.5,
                    "Weakening the secondary text role against its surface makes supporting Studio copy unreadable."
                )
                XCTAssertGreaterThanOrEqual(
                    contrastRatio(palette.accentFilledForeground, palette.accentFilled, traits: traits),
                    4.5,
                    "Weakening the filled action foreground role makes primary Studio actions unreadable."
                )
            }
        }
    }

    func test_typographyScalesForAccessibilityWithoutShrinkingLabels() {
        let standardTraits = UITraitCollection(preferredContentSizeCategory: .large)
        let accessibilityTraits = UITraitCollection(
            preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge
        )
        let standard = StudioTypography.font(.body, compatibleWith: standardTraits)
        let accessibility = StudioTypography.font(.body, compatibleWith: accessibilityTraits)
        let label = StudioTypography.makeLabel(.body, color: .label, text: "A longer label")

        XCTAssertGreaterThan(
            accessibility.pointSize,
            standard.pointSize,
            "Removing UIFontMetrics scaling makes Studio text stop growing at accessibility sizes."
        )
        XCTAssertTrue(label.adjustsFontForContentSizeCategory, "Turning off Dynamic Type on Studio labels makes user-selected text sizes ineffective.")
        XCTAssertFalse(label.adjustsFontSizeToFitWidth, "Shrinking Studio labels to fit reverses the user's Dynamic Type choice.")
        XCTAssertEqual(label.numberOfLines, 0, "Restricting Studio labels to one line clips long localized text at accessibility sizes.")
    }

    func test_selectedTileKeepsVisibleBorderAndCheckmarkSelectionCues() throws {
        let tile = StudioTileView(title: "Regular", isSelected: true)

        XCTAssertEqual(
            tile.layer.borderWidth,
            StudioMetrics.Size.borderSelected,
            "Removing the selected border leaves tile selection dependent on its fill color."
        )
        XCTAssertEqual(
            try XCTUnwrap(tile.layer.borderColor),
            tile.palette.accent.resolvedColor(with: tile.traitCollection).cgColor,
            "Removing the selected border color leaves a thicker but invisible selection border."
        )
        XCTAssertTrue(
            tile.accessibilityTraits.contains(.selected),
            "Removing the selected accessibility trait makes tile selection depend on color alone."
        )
        let checkmark = try XCTUnwrap(
            imageViews(in: tile).first { !$0.isHidden && $0.image != nil },
            "Removing the visible selection checkmark leaves tile selection dependent on border or color alone."
        )
        XCTAssertNotNil(checkmark.image, "Removing the visible selection checkmark leaves tile selection dependent on border or color alone.")
    }

    func test_selectedWidthTileKeepsItsPercentageAccessibilityValue() {
        let tile = StudioTileView(title: "Full", subtitle: "100%")
        tile.accessibilityValue = "100%"

        tile.isSelected = true

        XCTAssertEqual(
            tile.accessibilityValue,
            "100%",
            "Refreshing a selected width tile must preserve its announced percentage."
        )
        XCTAssertTrue(tile.accessibilityTraits.contains(.selected))
    }

    func test_interactiveStudioControlsMeetMinimumTouchHeight() {
        let controls: [UIView] = [
            StudioButton(title: "Continue"),
            StudioRowView(title: "Appearance"),
            StudioTileView(title: "Regular"),
            StudioSegmentedControl(titles: ["Compact", "Regular"])
        ]

        for control in controls {
            XCTAssertGreaterThanOrEqual(
                fittingHeight(of: control),
                StudioMetrics.Size.minTouchTarget,
                "Removing the minimum height from a Studio control makes it too small to activate reliably."
            )
        }
    }

    private func fittingHeight(of view: UIView) -> CGFloat {
        let host = UIView()
        host.addSubview(view)
        NSLayoutConstraint.activate([
            host.widthAnchor.constraint(equalToConstant: 320),
            view.topAnchor.constraint(equalTo: host.topAnchor),
            view.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
        return host.systemLayoutSizeFitting(
            CGSize(width: 320, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
    }

    private func imageViews(in view: UIView) -> [UIImageView] {
        view.subviews.flatMap { child in
            let imageView = child as? UIImageView
            return (imageView.map { [$0] } ?? []) + imageViews(in: child)
        }
    }

    private func accessibilityIdentifiers(in view: UIView) -> [String] {
        let own = view.accessibilityIdentifier.map { [$0] } ?? []
        return own + view.subviews.flatMap(accessibilityIdentifiers(in:))
    }

    private func contrastRatio(_ foreground: UIColor, _ background: UIColor, traits: UITraitCollection) -> CGFloat {
        let foregroundLuminance = relativeLuminance(of: foreground.resolvedColor(with: traits))
        let backgroundLuminance = relativeLuminance(of: background.resolvedColor(with: traits))
        return (max(foregroundLuminance, backgroundLuminance) + 0.05)
            / (min(foregroundLuminance, backgroundLuminance) + 0.05)
    }

    private func relativeLuminance(of color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        let channels = [red, green, blue].map { channel in
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }
}
