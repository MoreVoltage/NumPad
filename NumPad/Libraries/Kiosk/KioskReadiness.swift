import Foundation

enum KioskReadiness {
    enum Status: Equatable { case ready, warning, blocked }

    struct Input: Equatable {
        var keyboardEnabled: Bool
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
        if !input.keyboardEnabled {
            reasons.append("Keyboard is not enabled")
        }
        if !input.profileApplies {
            reasons.append("Active profile cannot apply")
        }
        if !input.keyboardEnabled || !input.profileApplies {
            return ReadinessReport(status: .blocked, reasons: reasons)
        }
        if !input.fullAccessConfirmed {
            reasons.append("Full Access not confirmed")
        }
        if input.usedEntitlementFallback {
            reasons.append("Entitlement fallback in effect")
        }
        if !input.tryItConfirmed {
            reasons.append("Try It field not confirmed on this device")
        }
        if !input.guidedAccessAcknowledged {
            reasons.append("Guided Access software keyboards not acknowledged")
        }
        if reasons.isEmpty {
            return ReadinessReport(status: .ready, reasons: [])
        }
        return ReadinessReport(status: .warning, reasons: reasons)
    }
}

