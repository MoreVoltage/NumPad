import Foundation

enum KioskReadiness {
    enum Status: Equatable {
        case ready, warning, blocked

        var localizedTitle: String {
            switch self {
            case .ready:
                return NSLocalizedString("Ready", comment: "Kiosk readiness status")
            case .warning:
                return NSLocalizedString("Needs Attention", comment: "Kiosk readiness status")
            case .blocked:
                return NSLocalizedString("Blocked", comment: "Kiosk readiness status")
            }
        }
    }

    struct Input: Equatable {
        var keyboardEnabled: Bool
        var activeProfileIsKiosk: Bool
        var kioskConfigurationIsValid: Bool
        var fullAccessConfirmed: Bool
        var profileApplies: Bool
        var usedEntitlementFallback: Bool
        var tryItConfirmed: Bool
        var guidedAccessAcknowledged: Bool
    }

    struct ReadinessReport: Equatable {
        var status: Status
        var reasons: [String]
    }

    static func evaluate(_ input: Input) -> ReadinessReport {
        var reasons: [String] = []
        if !input.activeProfileIsKiosk {
            reasons.append(NSLocalizedString(
                "Active profile is not Kiosk",
                comment: "Kiosk readiness blocking reason"
            ))
        }
        if input.activeProfileIsKiosk, !input.kioskConfigurationIsValid {
            reasons.append(NSLocalizedString(
                "Active Kiosk policy or configuration is invalid",
                comment: "Kiosk readiness blocking reason"
            ))
        }
        if !input.keyboardEnabled {
            reasons.append(NSLocalizedString(
                "Keyboard is not enabled",
                comment: "Kiosk readiness blocking reason"
            ))
        }
        if !input.profileApplies {
            reasons.append(NSLocalizedString(
                "Active profile cannot apply",
                comment: "Kiosk readiness blocking reason"
            ))
        }
        if !input.activeProfileIsKiosk
            || (input.activeProfileIsKiosk && !input.kioskConfigurationIsValid)
            || !input.keyboardEnabled || !input.profileApplies {
            return ReadinessReport(status: .blocked, reasons: reasons)
        }
        if !input.fullAccessConfirmed {
            reasons.append(NSLocalizedString(
                "Full Access not confirmed",
                comment: "Kiosk readiness warning reason"
            ))
        }
        if input.usedEntitlementFallback {
            reasons.append(NSLocalizedString(
                "Entitlement fallback in effect",
                comment: "Kiosk readiness warning reason"
            ))
        }
        if !input.tryItConfirmed {
            reasons.append(NSLocalizedString(
                "Try It field not confirmed on this device",
                comment: "Kiosk readiness warning reason"
            ))
        }
        if !input.guidedAccessAcknowledged {
            reasons.append(NSLocalizedString(
                "Guided Access software keyboards not acknowledged",
                comment: "Kiosk readiness warning reason"
            ))
        }
        if reasons.isEmpty {
            return ReadinessReport(status: .ready, reasons: [])
        }
        return ReadinessReport(status: .warning, reasons: reasons)
    }
}
