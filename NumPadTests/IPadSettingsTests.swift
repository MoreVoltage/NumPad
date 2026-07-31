//
//  IPadSettingsTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class IPadSettingsTests: XCTestCase {
    func test_iPadStudioLayoutCentersFiveNumpadWidthsWithoutChangingDockHeight() {
        let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 834)
        let expectedWidths: [(NumpadWidthSize, CGFloat)] = [
            (.compact, 600),
            (.comfortable, 700),
            (.medium, 800),
            (.wide, 900),
            (.full, 1_000),
        ]

        for heightPreset in KeyboardHeightPreset.allCases {
            let baseline = IPadStudioLayout.resolve(.init(
                bounds: bounds,
                safeAreaInsets: .zero,
                horizontalSizeClass: .regular,
                numpadWidthSize: .full,
                heightPreset: heightPreset
            ))

            for (width, expectedDockWidth) in expectedWidths {
                let layout = IPadStudioLayout.resolve(.init(
                    bounds: bounds,
                    safeAreaInsets: .zero,
                    horizontalSizeClass: .regular,
                    numpadWidthSize: width,
                    heightPreset: heightPreset
                ))

                XCTAssertEqual(layout.dockFrame.width, expectedDockWidth, accuracy: 0.001, "\(heightPreset), \(width)")
                XCTAssertEqual(layout.dockFrame.midX, bounds.midX, accuracy: 0.001, "\(heightPreset), \(width)")
                XCTAssertEqual(layout.dockHeight, baseline.dockHeight, accuracy: 0.001, "\(heightPreset), \(width)")
            }
        }
    }

    func test_iPadStudioLayoutKeepsTheBottomDockStructuralInRegularLandscape() {
        let layout = IPadStudioLayout.resolve(.init(
            bounds: CGRect(x: 0, y: 0, width: 1_194, height: 834),
            safeAreaInsets: UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0),
            horizontalSizeClass: .regular,
            numpadWidthSize: .compact,
            heightPreset: .regular
        ))

        XCTAssertEqual(layout.upperPresentation, .canvasAndInspector)
        XCTAssertTrue(layout.showsUtilityRails)
        XCTAssertTrue(layout.dockIsStructuralSibling)
        XCTAssertTrue(layout.dockPinsToSafeAreaBottom)
        XCTAssertGreaterThan(layout.upperContentBottomInset, 0)
    }

    func test_iPadStudioLayoutUsesOneScrollableColumnForPortraitAndMultitaskingWidths() {
        for width in [834.0, 512.0, 375.0] {
            let layout = IPadStudioLayout.resolve(.init(
                bounds: CGRect(x: 0, y: 0, width: width, height: 1_119),
                safeAreaInsets: UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0),
                horizontalSizeClass: width < 500 ? .compact : .regular,
                numpadWidthSize: .full,
                heightPreset: .regular
            ))

            XCTAssertNotEqual(layout.upperPresentation, .canvasAndInspector, "width \(width) must not use the landscape workspace")
            XCTAssertTrue(layout.dockIsStructuralSibling)
            XCTAssertTrue(layout.dockPinsToSafeAreaBottom)
            XCTAssertGreaterThan(layout.upperContentBottomInset, 0)
        }
    }

    func test_iPadStudioLayoutUsesSelectedWidthUntilThePreviewBecomesNarrow() {
        let wide = IPadStudioLayout.resolve(.init(
            bounds: CGRect(x: 0, y: 0, width: 1_194, height: 834),
            safeAreaInsets: .zero,
            horizontalSizeClass: .regular,
            numpadWidthSize: .compact,
            heightPreset: .tall
        ))
        let narrow = IPadStudioLayout.resolve(.init(
            bounds: CGRect(x: 0, y: 0, width: 400, height: 834),
            safeAreaInsets: .zero,
            horizontalSizeClass: .compact,
            numpadWidthSize: .compact,
            heightPreset: .tall
        ))

        XCTAssertEqual(wide.dockFrame.width, 1_194 * 0.60, accuracy: 0.5)
        XCTAssertEqual(wide.dockFrame.midX, 597, accuracy: 0.5)
        XCTAssertTrue(wide.showsUtilityRails)
        XCTAssertEqual(narrow.dockFrame.width, 400, accuracy: 0.5)
        XCTAssertFalse(narrow.showsUtilityRails)
        XCTAssertGreaterThan(narrow.dockFrame.width, 0)
    }

    func test_iPadStudioLayoutCentersSelectedWidthsAcrossTheRegularDock() {
        func resolve(_ width: NumpadWidthSize) -> IPadStudioLayout {
            IPadStudioLayout.resolve(.init(
                bounds: CGRect(x: 0, y: 0, width: 1_194, height: 834),
                safeAreaInsets: .zero,
                horizontalSizeClass: .regular,
                numpadWidthSize: width,
                heightPreset: .regular
            ))
        }

        let compact = resolve(.compact)
        let medium = resolve(.medium)
        let full = resolve(.full)

        XCTAssertEqual(compact.dockFrame.midX, 597, accuracy: 0.5)
        XCTAssertEqual(medium.dockFrame.midX, 597, accuracy: 0.5)
        XCTAssertEqual(full.dockFrame.midX, 597, accuracy: 0.5)
        XCTAssertLessThan(compact.dockFrame.width, medium.dockFrame.width)
        XCTAssertLessThan(medium.dockFrame.width, full.dockFrame.width)
    }

    func test_iPadStudioLayoutAccountsForSafeAreaAndDockHeightInReachableScrollInset() {
        let small = IPadStudioLayout.resolve(.init(
            bounds: CGRect(x: 0, y: 0, width: 834, height: 1_119),
            safeAreaInsets: UIEdgeInsets(top: 24, left: 0, bottom: 34, right: 0),
            horizontalSizeClass: .regular,
            numpadWidthSize: .full,
            heightPreset: .small
        ))
        let kiosk = IPadStudioLayout.resolve(.init(
            bounds: CGRect(x: 0, y: 0, width: 834, height: 1_119),
            safeAreaInsets: UIEdgeInsets(top: 24, left: 0, bottom: 34, right: 0),
            horizontalSizeClass: .regular,
            numpadWidthSize: .full,
            heightPreset: .kiosk
        ))

        XCTAssertEqual(kiosk.dockFrame.maxY, 1_085, accuracy: 0.5)
        XCTAssertGreaterThan(kiosk.dockHeight, small.dockHeight)
        // The destination scroll view already ends at the dock's top edge. It only needs the
        // small breathing clearance, not a second reservation for the entire dock.
        XCTAssertEqual(kiosk.upperContentBottomInset, 24, accuracy: 0.5)
    }

    func test_iPadStudioLayoutCapsKioskDockToReserveUsableUpperWorkspaceInShortWindows() {
        let shortKiosk = IPadStudioLayout.resolve(.init(
            bounds: CGRect(x: 0, y: 0, width: 834, height: 320),
            safeAreaInsets: .zero,
            horizontalSizeClass: .compact,
            numpadWidthSize: .full,
            heightPreset: .kiosk
        ))
        let restoredKiosk = IPadStudioLayout.resolve(.init(
            // 196pt reserve + 299pt requested Kiosk dock: this is the first safe height at
            // which the requested dock must be fully restored.
            bounds: CGRect(x: 0, y: 0, width: 834, height: 495),
            safeAreaInsets: .zero,
            horizontalSizeClass: .compact,
            numpadWidthSize: .full,
            heightPreset: .kiosk
        ))

        let requiredUpperHeight = IPadStudioLayout.compactChromeHeight
            + IPadStudioLayout.navigationBarAllowance
            + IPadStudioLayout.meaningfulDestinationViewportHeight
        XCTAssertEqual(IPadStudioLayout.minimumUpperWorkspaceHeight, requiredUpperHeight, accuracy: 0.5)
        XCTAssertEqual(IPadStudioLayout.minimumUpperWorkspaceHeight, 196, accuracy: 0.5)
        XCTAssertEqual(shortKiosk.dockHeight, 124, accuracy: 0.5)
        XCTAssertEqual(shortKiosk.dockFrame.minY, 196, accuracy: 0.5)
        XCTAssertEqual(restoredKiosk.dockHeight, 299, accuracy: 0.5)
    }

    func test_iPadStudioLayoutUsesTheSameUpperReserveForShortSafeAreaInsets() {
        let layout = IPadStudioLayout.resolve(.init(
            bounds: CGRect(x: 0, y: 0, width: 834, height: 364),
            safeAreaInsets: UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0),
            horizontalSizeClass: .compact,
            numpadWidthSize: .full,
            heightPreset: .kiosk
        ))

        XCTAssertEqual(layout.dockHeight, 124, accuracy: 0.5)
        XCTAssertEqual(layout.dockFrame.minY, 220, accuracy: 0.5)
        XCTAssertEqual(layout.dockFrame.maxY, 344, accuracy: 0.5)
    }

    func test_iPadStudioWorkspacePinsDockOutsideTheScrollableUpperSurface() {
        let workspace = IPadStudioWorkspaceViewController()
        let host = workspaceHost(for: workspace, size: CGSize(width: 1_194, height: 834))

        XCTAssertTrue(workspace.view.subviews.contains(workspace.dockView))
        XCTAssertFalse(workspace.upperScrollView.subviews.contains(workspace.dockView))
        XCTAssertEqual(
            workspace.dockView.frame.maxY,
            workspace.view.safeAreaLayoutGuide.layoutFrame.maxY,
            accuracy: 1
        )
        XCTAssertEqual(workspace.upperScrollView.contentInset.bottom, 24, accuracy: 0.5)
        XCTAssertTrue(host.children.contains(workspace))
    }

    func test_iPadStudioWorkspaceEmbedsAdvancedWithoutCoveringTheDock() {
        let workspace = IPadStudioWorkspaceViewController()
        _ = workspaceHost(for: workspace, size: CGSize(width: 1_194, height: 834))

        workspace.showAdvanced()

        XCTAssertTrue(workspace.activeNavigationController.topViewController is AdvancedStudioViewController)
        XCTAssertNil(workspace.presentedViewController)
        XCTAssertTrue(workspace.view.subviews.contains(workspace.dockView))
        XCTAssertFalse(workspace.dockView.isHidden)
    }

    func test_iPadRailAdvancedHasAnIdentifierDistinctFromKeyboardGear() {
        let workspace = IPadStudioWorkspaceViewController()
        _ = workspaceHost(for: workspace, size: CGSize(width: 1_194, height: 834))

        let railAdvanced = view(withAccessibilityIdentifier: "studio.ipad.rail.advanced", in: workspace.view)
        let keyboardGear = try? XCTUnwrap(
            (workspace.activeNavigationController.topViewController as? KeyboardStudioViewController)?
                .navigationItem.rightBarButtonItem
        )

        XCTAssertNotNil(railAdvanced)
        XCTAssertEqual(keyboardGear?.accessibilityIdentifier, "studio.keyboard.advanced")
        XCTAssertNotEqual(railAdvanced?.accessibilityIdentifier, keyboardGear?.accessibilityIdentifier)
    }

    func test_iPadKeyboardGearRoutesAdvancedIntoTheWorkspaceInsteadOfPresenting() throws {
        let workspace = IPadStudioWorkspaceViewController()
        _ = workspaceHost(for: workspace, size: CGSize(width: 1_194, height: 834))
        let keyboard = try XCTUnwrap(
            workspace.activeNavigationController.topViewController as? KeyboardStudioViewController
        )
        let gear = try XCTUnwrap(keyboard.navigationItem.rightBarButtonItem)
        let action = try XCTUnwrap(gear.action)

        _ = keyboard.perform(action)

        XCTAssertTrue(workspace.activeNavigationController.topViewController is AdvancedStudioViewController)
        XCTAssertNil(workspace.presentedViewController)
        XCTAssertTrue(workspace.dockView.isDescendant(of: workspace.view))
    }

    func test_iPadStudioWorkspaceRefreshesOneDockForTraitAndSettingsUpdates() {
        let workspace = IPadStudioWorkspaceViewController()
        _ = workspaceHost(for: workspace, size: CGSize(width: 1_194, height: 834))
        let dock = workspace.dockView
        let observerCount = workspace.settingsObserverRegistrationCount

        workspace.refreshWorkspace()
        workspace.refreshWorkspace()

        XCTAssertTrue(workspace.dockView === dock)
        XCTAssertEqual(workspace.settingsObserverRegistrationCount, observerCount)
        XCTAssertEqual(workspace.dockView.preview.model, .current(idiom: .pad))
    }

    func test_iPadWorkspaceHasNoRailPreviewAndInjectsNoInlinePreviewIntoKeyboard() throws {
        let workspace = IPadStudioWorkspaceViewController()
        _ = workspaceHost(for: workspace, size: CGSize(width: 1_194, height: 834))

        XCTAssertNil(view(withAccessibilityIdentifier: "studio.ipad.canvas", in: workspace.view))
        let keyboard = try XCTUnwrap(workspace.activeNavigationController.topViewController as? KeyboardStudioViewController)
        XCTAssertNil(view(withAccessibilityIdentifier: "studio.keyboard.preview", in: keyboard.view))
        XCTAssertTrue(workspace.dockView.isDescendant(of: workspace.view))
    }

    func test_contextSpecificDockPreservesCurrentWidthAndFullKeyboardSide() {
        let oldProOverride = Monetization.debugProOverride
        let oldRemoteEnabled = FeatureFlags.fullKeyboardRemoteEnabled
        defer {
            Monetization.debugProOverride = oldProOverride
            FeatureFlags.fullKeyboardRemoteEnabled = oldRemoteEnabled
        }
        Monetization.debugProOverride = true
        FeatureFlags.fullKeyboardRemoteEnabled = true
        let defaults = UserDefaults.group
        let keys = [
            Constants.numpadWidthSize.rawValue,
            Constants.iPadQwertyLayout.rawValue,
            Constants.fullKeyboardNumpadSide.rawValue,
            Constants.keyboardPage.rawValue
        ]
        let before = keys.reduce(into: [String: Any]()) { values, key in
            if let value = defaults.object(forKey: key) { values[key] = value }
        }
        defer {
            keys.forEach(defaults.removeObject(forKey:))
            before.forEach { defaults.set($0.value, forKey: $0.key) }
        }
        defaults.set(NumpadWidthSize.compact.rawValue, forKey: Constants.numpadWidthSize.rawValue)
        defaults.set(IPadQwertyLayout.full.rawValue, forKey: Constants.iPadQwertyLayout.rawValue)
        defaults.set(FullKeyboardNumpadSide.left.rawValue, forKey: Constants.fullKeyboardNumpadSide.rawValue)
        defaults.set("qwerty", forKey: Constants.keyboardPage.rawValue)

        let workspace = IPadStudioWorkspaceViewController()
        _ = workspaceHost(for: workspace, size: CGSize(width: 1_194, height: 834))

        StudioPreviewContext.request(.numpad)
        XCTAssertEqual(workspace.dockView.preview.model.page, .numpad)
        XCTAssertEqual(workspace.dockView.preview.model.numpadWidthSize, .compact)

        StudioPreviewContext.request(.qwerty)
        XCTAssertEqual(workspace.dockView.preview.model.page, .qwerty)
        XCTAssertEqual(workspace.dockView.preview.model.iPadQwertyLayout, .full)
        XCTAssertEqual(workspace.dockView.preview.model.fullKeyboardNumpadSide, .left)
    }

    func test_iPadNumpadEditorsReplaceAStaleQwertyDockContext() {
        let oldProOverride = Monetization.debugProOverride
        let oldRemoteEnabled = FeatureFlags.fullKeyboardRemoteEnabled
        defer {
            Monetization.debugProOverride = oldProOverride
            FeatureFlags.fullKeyboardRemoteEnabled = oldRemoteEnabled
        }
        Monetization.debugProOverride = true
        FeatureFlags.fullKeyboardRemoteEnabled = true
        let workspace = IPadStudioWorkspaceViewController()
        _ = workspaceHost(for: workspace, size: CGSize(width: 1_194, height: 834))

        StudioPreviewContext.request(.qwerty)
        XCTAssertEqual(workspace.dockView.preview.model.page, .qwerty)

        for editor in [
            AppearanceStudioViewController(showsInlinePreview: false),
            KeySetStudioViewController(showsInlinePreview: false)
        ] {
            workspace.activeNavigationController.pushViewController(editor, animated: false)
            editor.viewWillAppear(false)
            XCTAssertEqual(workspace.dockView.preview.model.page, .numpad)
        }

        StudioPreviewContext.request(.qwerty)
        let theme = ThemeViewController()
        workspace.activeNavigationController.pushViewController(theme, animated: false)
        theme.viewWillAppear(false)
        XCTAssertEqual(workspace.dockView.preview.model.page, .numpad)
    }

    func test_navigatingFromLettersToSizeAndFeelImmediatelyReturnsTheExistingDockToNumpad() {
        let oldProOverride = Monetization.debugProOverride
        let oldRemoteEnabled = FeatureFlags.fullKeyboardRemoteEnabled
        defer {
            Monetization.debugProOverride = oldProOverride
            FeatureFlags.fullKeyboardRemoteEnabled = oldRemoteEnabled
        }
        Monetization.debugProOverride = true
        FeatureFlags.fullKeyboardRemoteEnabled = true

        let workspace = IPadStudioWorkspaceViewController()
        _ = workspaceHost(for: workspace, size: CGSize(width: 1_194, height: 834))
        let dock = workspace.dockView
        let letters = LettersStudioViewController()
        workspace.activeNavigationController.pushViewController(letters, animated: false)
        letters.viewWillAppear(false)
        XCTAssertEqual(dock.preview.model.page, .qwerty)

        let sizeAndFeel = SizeAndFeelStudioViewController()
        workspace.activeNavigationController.setOverrideTraitCollection(
            UITraitCollection(userInterfaceIdiom: .pad),
            forChild: sizeAndFeel
        )
        workspace.activeNavigationController.pushViewController(sizeAndFeel, animated: false)
        sizeAndFeel.viewWillAppear(false)

        XCTAssertTrue(workspace.dockView === dock)
        XCTAssertEqual(dock.preview.model.page, .numpad)
    }

    func test_dashboardCentersReadableContentAtRegularWidth() {
        let dashboard = DashboardViewController()
        dashboard.loadViewIfNeeded()
        dashboard.view.frame = CGRect(x: 0, y: 0, width: 1_024, height: 768)
        dashboard.view.layoutIfNeeded()

        let frame = dashboard.contentTableView.frame
        XCTAssertEqual(frame.width, DashboardViewController.maximumReadableContentWidth, accuracy: 1)
        XCTAssertEqual(frame.midX, dashboard.view.bounds.midX, accuracy: 1)
    }

    func test_dashboardFillsNarrowSplitDetailWithoutClipping() {
        let dashboard = DashboardViewController()
        dashboard.loadViewIfNeeded()
        dashboard.view.frame = CGRect(x: 0, y: 0, width: 420, height: 700)
        dashboard.view.layoutIfNeeded()

        let frame = dashboard.contentTableView.frame
        XCTAssertEqual(frame.minX, 0, accuracy: 1)
        XCTAssertEqual(frame.maxX, dashboard.view.bounds.maxX, accuracy: 1)
    }

    func test_dashboardKeepsKioskSummaryInInitialViewport() {
        let dashboard = DashboardViewController()
        dashboard.loadViewIfNeeded()
        dashboard.view.frame = CGRect(x: 0, y: 0, width: 680, height: 600)
        dashboard.view.layoutIfNeeded()

        let summary = dashboard.contentTableView.cellForRow(
            at: DashboardViewController.kioskSummaryIndexPath
        )
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.accessibilityIdentifier, "dashboard.kioskReadiness")
        XCTAssertLessThanOrEqual(summary?.frame.maxY ?? .greatestFiniteMagnitude, 600)
    }

    func test_dashboardInteractiveControlsMeetAccessibilityContract() {
        let dashboard = DashboardViewController()
        dashboard.loadViewIfNeeded()
        dashboard.view.frame = CGRect(x: 0, y: 0, width: 680, height: 900)
        dashboard.view.layoutIfNeeded()

        XCTAssertEqual(dashboard.contentTableView.rowHeight, UITableView.automaticDimension)
        XCTAssertTrue(dashboard.tryItTextField.adjustsFontForContentSizeCategory)
        XCTAssertFalse(dashboard.tryItTextField.accessibilityLabel?.isEmpty ?? true)
        XCTAssertFalse(dashboard.tryItTextField.accessibilityHint?.isEmpty ?? true)

        let profiles = dashboard.contentTableView.cellForRow(
            at: DashboardViewController.profilesIndexPath
        )
        let kiosk = dashboard.contentTableView.cellForRow(
            at: DashboardViewController.kioskProvisioningIndexPath
        )
        XCTAssertTrue(profiles?.accessibilityTraits.contains(.button) == true)
        XCTAssertGreaterThanOrEqual(profiles?.frame.height ?? 0, 44)
        XCTAssertFalse(profiles?.accessibilityHint?.isEmpty ?? true)
        XCTAssertTrue(kiosk?.accessibilityTraits.contains(.button) == true)
        XCTAssertGreaterThanOrEqual(kiosk?.frame.height ?? 0, 44)
        XCTAssertFalse(kiosk?.accessibilityHint?.isEmpty ?? true)
    }

    func test_dashboardReflowsAtAccessibilityXXXLInNarrowSplitAndAfterRotation() {
        let dashboard = DashboardViewController()
        let host = accessibilityHost(for: dashboard, size: CGSize(width: 320, height: 720))

        assertTableContentFits(dashboard.contentTableView)
        for cell in dashboard.contentTableView.visibleCells where cell.reuseIdentifier == "Dash" {
            XCTAssertEqual(cell.textLabel?.numberOfLines, 0)
            XCTAssertEqual(cell.detailTextLabel?.numberOfLines, 0)
            XCTAssertGreaterThanOrEqual(cell.frame.height, 44)
        }

        host.view.frame = CGRect(x: 0, y: 0, width: 720, height: 320)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        dashboard.view.setNeedsLayout()
        dashboard.view.layoutIfNeeded()

        assertTableContentFits(dashboard.contentTableView)
        XCTAssertEqual(dashboard.contentTableView.frame.width, 720, accuracy: 1)
    }

    func test_sidebarReflowsAtAccessibilityXXXLInNarrowPrimaryColumn() {
        let sections = HomeSettingsModel.sections(fullKeyboardVisible: true, isPad: true)
        let sidebar = SettingsSidebarController(sections: sections) { _ in }
        _ = accessibilityHost(for: sidebar, size: CGSize(width: 280, height: 720))

        XCTAssertEqual(sidebar.tableView.rowHeight, UITableView.automaticDimension)
        sidebar.tableView.reloadData()
        sidebar.tableView.layoutIfNeeded()
        for cell in sidebar.tableView.visibleCells {
            XCTAssertGreaterThanOrEqual(cell.frame.height, 44)
            XCTAssertLessThanOrEqual(cell.frame.maxX, sidebar.tableView.bounds.maxX)
        }
        for section in sections.indices {
            for row in sections[section].rows.indices {
                let cell = sidebar.tableView(
                    sidebar.tableView,
                    cellForRowAt: IndexPath(row: row, section: section)
                )
                XCTAssertEqual(cell.textLabel?.numberOfLines, 0)
            }
        }
    }

    func test_iPadTransitionsDisableAnimationForReduceMotion() {
        XCTAssertFalse(
            IPadSettingsSplitViewController.shouldAnimateTransition(reduceMotionEnabled: true)
        )
        XCTAssertTrue(
            IPadSettingsSplitViewController.shouldAnimateTransition(reduceMotionEnabled: false)
        )
    }

    func test_iPadAccessibilityStringsExistInEverySupportedLocalizationTable() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let numPadRoot = projectRoot.appendingPathComponent("NumPad")
        let presentationSources = [
            "Controllers/DashboardViewController.swift",
            "Controllers/IPadSettingsSplitViewController.swift",
            "Libraries/Kiosk/KioskReadiness.swift",
            "Libraries/KeyboardStatusPresentation.swift",
            "Libraries/Settings/HomeSettingsModel.swift"
        ]
        let localizedLiteralPattern = try NSRegularExpression(
            pattern: #"NSLocalizedString\(\s*"((?:\\.|[^"])*)""#
        )
        var sourceKeys = Set<String>()
        for sourcePath in presentationSources {
            let source = try String(
                contentsOf: numPadRoot.appendingPathComponent(sourcePath),
                encoding: .utf8
            )
            let range = NSRange(source.startIndex..., in: source)
            for match in localizedLiteralPattern.matches(in: source, range: range) {
                guard
                    let matchRange = Range(match.range(at: 1), in: source)
                else { continue }
                sourceKeys.insert(String(source[matchRange]))
            }
        }
        XCTAssertTrue(
            sourceKeys.isSubset(of: Set(IPadPresentationLocalization.requiredKeys)),
            "Add every iPad presentation literal to the all-locales gate: "
                + sourceKeys.subtracting(IPadPresentationLocalization.requiredKeys).sorted()
                    .joined(separator: ", ")
        )

        let localizationDirectories = try FileManager.default.contentsOfDirectory(
            at: numPadRoot,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "lproj" }
        let localizations = localizationDirectories.filter {
            FileManager.default.fileExists(
                atPath: $0.appendingPathComponent("Localizable.strings").path
            )
        }

        XCTAssertEqual(localizations.count, 16, "Update this gate when supported locales change")
        for localization in localizations {
            let tableURL = localization.appendingPathComponent("Localizable.strings")
            let table = NSDictionary(contentsOf: tableURL) as? [String: String]
            XCTAssertNotNil(table, "Invalid localization table: \(tableURL.path)")
            XCTAssertGreaterThanOrEqual(
                IPadPresentationLocalization.requiredKeys.count,
                50,
                "Keep the gate aligned with the complete iPad presentation surface"
            )
            for key in IPadPresentationLocalization.requiredKeys {
                XCTAssertNotNil(
                    table?[key],
                    "Missing \(key.debugDescription) in \(localization.lastPathComponent)"
                )
                XCTAssertFalse(
                    table?[key]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true,
                    "Empty \(key.debugDescription) in \(localization.lastPathComponent)"
                )
                XCTAssertEqual(
                    table?[key]?.components(separatedBy: "%@").count,
                    key.components(separatedBy: "%@").count,
                    "Placeholder mismatch for \(key.debugDescription) in "
                        + localization.lastPathComponent
                )
                if localization.lastPathComponent != "en.lproj", key.count > 25 {
                    XCTAssertNotEqual(
                        table?[key],
                        key,
                        "Untranslated prose \(key.debugDescription) in "
                            + localization.lastPathComponent
                    )
                }
            }
        }
    }

    func test_studioAndOnboardingDirectLocalizationInventoryIsCompleteAndValid() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let numPadRoot = projectRoot.appendingPathComponent("NumPad")
        let sourcePaths = [
            "Controllers/Studio/AdvancedStudioViewController.swift",
            "Controllers/Studio/AppearanceStudioViewController.swift",
            "Controllers/Studio/FeaturesStudioViewController.swift",
            "Controllers/Studio/HelpStudioViewController.swift",
            "Controllers/Studio/IPadStudioWorkspaceViewController.swift",
            "Controllers/Studio/KeySetStudioViewController.swift",
            "Controllers/Studio/KeyboardStudioViewController.swift",
            "Controllers/Studio/LettersStudioViewController.swift",
            "Controllers/Studio/MoveSetupsViewController.swift",
            "Controllers/Studio/SavedSetupDetailViewController.swift",
            "Controllers/Studio/SavedSetupsStudioViewController.swift",
            "Controllers/Studio/SizeAndFeelStudioViewController.swift",
            "Controllers/Studio/StudioNavigationFactory.swift",
            "Controllers/Studio/StudioTabBarController.swift",
            "Libraries/DesignSystem/StudioButton.swift",
            "Libraries/DesignSystem/StudioCard.swift",
            "Libraries/DesignSystem/StudioMetrics.swift",
            "Libraries/DesignSystem/StudioRowView.swift",
            "Libraries/DesignSystem/StudioSectionLabel.swift",
            "Libraries/DesignSystem/StudioSegmentedControl.swift",
            "Libraries/DesignSystem/StudioStatusHeroView.swift",
            "Libraries/DesignSystem/StudioTagView.swift",
            "Libraries/DesignSystem/StudioTheme.swift",
            "Libraries/DesignSystem/StudioTileView.swift",
            "Libraries/DesignSystem/StudioTypography.swift",
            "Libraries/Studio/IPadStudioLayout.swift",
            "Libraries/Studio/StudioKeySetCatalog.swift",
            "Libraries/Studio/StudioSavedSetupPresentation.swift",
            "Libraries/Studio/StudioSettingsWriter.swift",
            "Views/StudioKeyboardPreviewView.swift",
            "Views/StudioKeyboardDockView.swift",
            "Libraries/StudioKeyboardPreviewModel.swift",
            "Controllers/OnboardingEnableViewController.swift",
            "Controllers/OnboardingHeightViewController.swift",
            "Controllers/OnboardingTryItViewController.swift",
            "Controllers/OnboardingViewController.swift",
            "Controllers/OnboardingWowViewController.swift"
        ]
        XCTAssertEqual(sourcePaths.count, 37, "Keep this explicit inventory reproducible")

        // Include rule: every Swift file recursively under the three Studio implementation
        // directories, the standalone Studio preview model/views, and every top-level controller
        // named Onboarding*ViewController.swift. The explicit set makes additions deliberate;
        // discovery prevents a new relevant source from being silently omitted from the audit.
        let recursivelyDiscoveredRoots = [
            "Controllers/Studio",
            "Libraries/DesignSystem",
            "Libraries/Studio"
        ]
        var discoveredSourcePaths = Set<String>()
        for relativeRoot in recursivelyDiscoveredRoots {
            let root = numPadRoot.appendingPathComponent(relativeRoot)
            let enumerator = try XCTUnwrap(
                FileManager.default.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
            )
            for case let sourceURL as URL in enumerator where sourceURL.pathExtension == "swift" {
                discoveredSourcePaths.insert(
                    String(sourceURL.path.dropFirst(numPadRoot.path.count + 1))
                )
            }
        }
        discoveredSourcePaths.formUnion([
            "Libraries/StudioKeyboardPreviewModel.swift",
            "Views/StudioKeyboardPreviewView.swift",
            "Views/StudioKeyboardDockView.swift"
        ])
        let controllerURLs = try FileManager.default.contentsOfDirectory(
            at: numPadRoot.appendingPathComponent("Controllers"),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        discoveredSourcePaths.formUnion(controllerURLs.compactMap { sourceURL in
            let name = sourceURL.lastPathComponent
            guard name.hasPrefix("Onboarding"), name.hasSuffix("ViewController.swift") else {
                return nil
            }
            return "Controllers/\(name)"
        })
        let expectedSourcePaths = Set(sourcePaths)
        XCTAssertEqual(
            discoveredSourcePaths,
            expectedSourcePaths,
            "Update the explicit Studio/onboarding inventory. Missing: "
                + expectedSourcePaths.subtracting(discoveredSourcePaths).sorted().joined(separator: ", ")
                + "; unexpected: "
                + discoveredSourcePaths.subtracting(expectedSourcePaths).sorted().joined(separator: ", ")
        )
        XCTAssertEqual(discoveredSourcePaths.count, 37)

        let localizedLiteralPattern = try NSRegularExpression(
            pattern: #"NSLocalizedString\(\s*"((?:\\.|[^"\\])*)""#
        )
        var directKeys = Set<String>()
        for sourcePath in discoveredSourcePaths.sorted() {
            let sourceURL = numPadRoot.appendingPathComponent(sourcePath)
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            let range = NSRange(source.startIndex..., in: source)
            for match in localizedLiteralPattern.matches(in: source, range: range) {
                guard let keyRange = Range(match.range(at: 1), in: source) else { continue }
                directKeys.insert(String(source[keyRange]))
            }
        }
        XCTAssertEqual(
            directKeys.count,
            144,
            "A changed direct-literal inventory requires catalog updates and an intentional count review"
        )

        let localizations = try FileManager.default.contentsOfDirectory(
            at: numPadRoot,
            includingPropertiesForKeys: nil
        ).filter {
            $0.pathExtension == "lproj" && FileManager.default.fileExists(
                atPath: $0.appendingPathComponent("Localizable.strings").path
            )
        }

        XCTAssertEqual(localizations.count, 16)
        let stringsKeyPattern = try NSRegularExpression(
            pattern: #"(?m)^\s*"((?:\\.|[^"\\])*)"\s*="#
        )
        let placeholderPattern = try NSRegularExpression(pattern: #"%(?:\d+\$)?@"#)
        for localization in localizations {
            let tableURL = localization.appendingPathComponent("Localizable.strings")
            let rawTable = try String(contentsOf: tableURL, encoding: .utf8)
            let rawRange = NSRange(rawTable.startIndex..., in: rawTable)
            let declaredKeys = stringsKeyPattern.matches(in: rawTable, range: rawRange).compactMap {
                Range($0.range(at: 1), in: rawTable).map { String(rawTable[$0]) }
            }
            var seen = Set<String>()
            let duplicates = declaredKeys.filter { !seen.insert($0).inserted }
            XCTAssertTrue(
                duplicates.isEmpty,
                "Duplicate keys in \(localization.lastPathComponent): \(duplicates.sorted())"
            )

            let table = NSDictionary(contentsOf: tableURL) as? [String: String]
            XCTAssertNotNil(table, "Invalid localization table: \(tableURL.path)")
            for key in directKeys {
                XCTAssertFalse(
                    table?[key]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true,
                    "Missing \(key.debugDescription) in \(localization.lastPathComponent)"
                )
                let keyRange = NSRange(key.startIndex..., in: key)
                let localizedValue = table?[key] ?? ""
                let valueRange = NSRange(localizedValue.startIndex..., in: localizedValue)
                XCTAssertEqual(
                    placeholderPattern.numberOfMatches(in: localizedValue, range: valueRange),
                    placeholderPattern.numberOfMatches(in: key, range: keyRange),
                    "Placeholder mismatch for \(key.debugDescription) in \(localization.lastPathComponent)"
                )
            }
        }
    }

    func test_publishedPrivacyCopiesAreIdenticalAndDescribeAvailableChoices() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let markdown = try String(
            contentsOf: projectRoot.appendingPathComponent("docs/PrivacyPolicy.md"),
            encoding: .utf8
        )
        let extensionless = try String(
            contentsOf: projectRoot.appendingPathComponent("docs/PrivacyPolicy"),
            encoding: .utf8
        )

        XCTAssertEqual(markdown, extensionless)
        XCTAssertFalse(markdown.contains("opt out of analytics collection"))
        XCTAssertFalse(
            markdown.contains(
                "request deletion of any data associated with your app instance"
            )
        )
        XCTAssertTrue(markdown.contains("does not provide an in-app analytics opt-out"))
        XCTAssertTrue(
            markdown.contains(
                "cannot identify or delete Firebase records for a particular person or device"
            )
        )
    }

    private func accessibilityHost(
        for child: UIViewController,
        size: CGSize
    ) -> UIViewController {
        let host = UIViewController()
        host.loadViewIfNeeded()
        host.view.frame = CGRect(origin: .zero, size: size)
        host.addChild(child)
        host.setOverrideTraitCollection(
            UITraitCollection(
                preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge
            ),
            forChild: child
        )
        child.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(child.view)
        NSLayoutConstraint.activate([
            child.view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            child.view.topAnchor.constraint(equalTo: host.view.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor)
        ])
        child.didMove(toParent: host)
        host.view.layoutIfNeeded()
        child.view.layoutIfNeeded()
        return host
    }

    private func workspaceHost(
        for child: UIViewController,
        size: CGSize
    ) -> UIViewController {
        let host = UIViewController()
        host.loadViewIfNeeded()
        host.view.frame = CGRect(origin: .zero, size: size)
        host.addChild(child)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(child.view)
        NSLayoutConstraint.activate([
            child.view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            child.view.topAnchor.constraint(equalTo: host.view.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor)
        ])
        child.didMove(toParent: host)
        host.view.layoutIfNeeded()
        child.view.layoutIfNeeded()
        return host
    }

    private func assertTableContentFits(
        _ tableView: UITableView,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(tableView.frame.minX, 0, file: file, line: line)
        XCTAssertLessThanOrEqual(
            tableView.frame.maxX,
            tableView.superview?.bounds.maxX ?? tableView.frame.maxX,
            file: file,
            line: line
        )
        for cell in tableView.visibleCells {
            XCTAssertGreaterThanOrEqual(cell.frame.minX, 0, file: file, line: line)
            XCTAssertLessThanOrEqual(
                cell.frame.maxX,
                tableView.bounds.maxX,
                file: file,
                line: line
            )
        }
    }

    private func view(withAccessibilityIdentifier identifier: String, in root: UIView?) -> UIView? {
        guard let root else { return nil }
        if root.accessibilityIdentifier == identifier { return root }
        for child in root.subviews {
            if let match = view(withAccessibilityIdentifier: identifier, in: child) {
                return match
            }
        }
        return nil
    }
}
