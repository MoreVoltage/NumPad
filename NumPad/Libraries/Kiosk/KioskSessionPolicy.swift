import Foundation

enum KioskSessionPolicy {
    enum ResetAction: Hashable {
        case dismissOverlays
        case resetPageAndPack
        case clearResultTape
        case clearClipboardHistory
    }

    static func actions(policy: KeyboardProfile.KioskPolicy,
                        lastInteraction: Date,
                        now: Date) -> Set<ResetAction> {
        guard now.timeIntervalSince(lastInteraction) >= policy.inactivityTimeout else {
            return []
        }
        var actions: Set<ResetAction> = []
        if policy.dismissOverlays { actions.insert(.dismissOverlays) }
        if policy.resetPageAndPack { actions.insert(.resetPageAndPack) }
        if policy.clearResultTape { actions.insert(.clearResultTape) }
        if policy.clearClipboardHistory { actions.insert(.clearClipboardHistory) }
        return actions
    }
}

