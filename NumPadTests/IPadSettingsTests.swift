//
//  IPadSettingsTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class IPadSettingsTests: XCTestCase {
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
}
