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
            for key in IPadAccessibilityLocalization.requiredKeys {
                XCTAssertNotNil(
                    table?[key],
                    "Missing \(key.debugDescription) in \(localization.lastPathComponent)"
                )
                XCTAssertFalse(
                    table?[key]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true,
                    "Empty \(key.debugDescription) in \(localization.lastPathComponent)"
                )
            }
        }
    }
}
