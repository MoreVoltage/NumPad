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
            // Phone: the section only holds the "Saved setups" row — no redundant header.
            guard rows.contains(.dashboard) else { return nil }
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

        // The Dashboard destination only has a handler on iPad (split detail). On the phone Home
        // shell the row was a dead tap, so the phone keeps just Saved setups in this section.
        let dashboardRows: [SettingsDestination] = isPad ? [.dashboard, .profiles] : [.profiles]
        var sections: [HomeSection] = [
            HomeSection(id: .dashboard, rows: dashboardRows),
            HomeSection(id: .keyboard, rows: keyboardRows),
        ]
        // Only NumPad Type (`.qwerty` above) follows the full-keyboard rollout flag. Typing &
        // Behavior is ALWAYS present: it hosts Haptics, Key Click Sound, Repurpose Next Key,
        // Inline Calculator, Live Math Preview, Cursor Controls, Smart Pack Defaulting, Result
        // Tape and iCloud Sync — the toggles live 2.1.1 showed in the Store's Settings section.
        // Gating it on the QWERTY flag made all of them unreachable in App Store builds.
        sections.append(HomeSection(id: .typingBehavior, rows: [.typingBehavior]))
        sections += [
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
