//
//  HomeSettingsModel.swift
//  NumPad
//

import Foundation

/// Destinations shared by the phone home table and the iPad split sidebar.
enum SettingsDestination: Hashable {
    case dashboard
    case profiles
    case keyboardSetup
    case theme
    case packs
    case height
    case numberOrder
    case roundedCorners
    case grid
    case customKeyboard
    case qwerty
    case typingBehavior
    case snippets
    case privacy
    case featureGuide
    case pro
    case feedback
    case rate
    case kioskProvisioning
}

struct HomeSection: Equatable {
    enum ID: String, Equatable {
        case dashboard
        case keyboard
        case typingBehavior
        case content
        case account
        case help
    }

    let id: ID
    let rows: [SettingsDestination]

    var title: String? {
        switch id {
        case .dashboard:
            return NSLocalizedString("Dashboard", comment: "Home settings section title")
        case .keyboard:
            return NSLocalizedString("Keyboard", comment: "Home settings section title")
        case .typingBehavior:
            return NSLocalizedString("Typing & Behavior", comment: "Home settings section title")
        case .content:
            return NSLocalizedString("Content & Automation", comment: "Home settings section title")
        case .account:
            return NSLocalizedString("Account", comment: "Home settings section title")
        case .help:
            return NSLocalizedString("Help", comment: "Home settings section title")
        }
    }
}

enum HomeSettingsModel {
    static func sections(fullKeyboardVisible: Bool, isPad: Bool) -> [HomeSection] {
        var keyboardRows: [SettingsDestination] = [
            .keyboardSetup, .theme, .packs, .height,
            .numberOrder, .roundedCorners, .grid, .customKeyboard
        ]
        if fullKeyboardVisible {
            keyboardRows.append(.qwerty)
        }

        var sections: [HomeSection] = [
            HomeSection(id: .dashboard, rows: [.dashboard, .profiles]),
            HomeSection(id: .keyboard, rows: keyboardRows),
            HomeSection(id: .typingBehavior, rows: [.typingBehavior]),
            HomeSection(id: .content, rows: [.snippets]),
            HomeSection(id: .account, rows: [.pro, .privacy]),
            HomeSection(id: .help, rows: [.featureGuide, .feedback, .rate])
        ]

        if isPad {
            // Kiosk provisioning is an iPad-oriented destination; phone can still deep-link later.
            if let helpIndex = sections.firstIndex(where: { $0.id == .help }) {
                var help = sections[helpIndex]
                help = HomeSection(id: .help, rows: help.rows + [.kioskProvisioning])
                sections[helpIndex] = help
            }
        }

        return sections
    }
}
