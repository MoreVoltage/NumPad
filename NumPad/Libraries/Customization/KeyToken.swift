import Foundation

/// Cursor-movement direction for a `KeyToken.cursor` action.
enum Direction: String, Codable, Equatable { case left, right, up, down }

/// Long-press overlays a key can trigger.
enum OverlayKind: String, Codable, Equatable { case clipboard, snippets, taxTip }

/// A single action a key can perform. Pure Foundation — `pack` stores a
/// `KeyboardType` rawValue string so the model stays UIKit-free and migration-stable.
enum KeyToken: Equatable {
    case digit(String)
    case op(String)
    case decimalSeparator
    case delete, ret, space, tab, hide, calc
    case cursor(Direction)
    case snippet(UUID)
    case pack(String)
    case overlay(OverlayKind)
    /// Forward-compat sink: an unrecognized token from a newer build decodes here.
    case noop
}

extension KeyToken: Codable {
    private enum CodingKeys: String, CodingKey { case kind, value }

    /// Stable discriminator written to disk. Never renamed without a migration.
    private var kind: String {
        switch self {
        case .digit: return "digit"
        case .op: return "op"
        case .decimalSeparator: return "decimalSeparator"
        case .delete: return "delete"
        case .ret: return "ret"
        case .space: return "space"
        case .tab: return "tab"
        case .hide: return "hide"
        case .calc: return "calc"
        case .cursor: return "cursor"
        case .snippet: return "snippet"
        case .pack: return "pack"
        case .overlay: return "overlay"
        case .noop: return "noop"
        }
    }

    /// The associated value, flattened to a string (absent for valueless cases).
    private var value: String? {
        switch self {
        case .digit(let s), .op(let s), .pack(let s): return s
        case .cursor(let d): return d.rawValue
        case .overlay(let o): return o.rawValue
        case .snippet(let id): return id.uuidString
        default: return nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        if let value { try container.encode(value, forKey: .value) }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        let value = try container.decodeIfPresent(String.self, forKey: .value)
        switch kind {
        case "digit": self = value.map(KeyToken.digit) ?? .noop
        case "op": self = value.map(KeyToken.op) ?? .noop
        case "pack": self = value.map(KeyToken.pack) ?? .noop
        case "decimalSeparator": self = .decimalSeparator
        case "delete": self = .delete
        case "ret": self = .ret
        case "space": self = .space
        case "tab": self = .tab
        case "hide": self = .hide
        case "calc": self = .calc
        case "noop": self = .noop
        case "cursor": self = value.flatMap(Direction.init(rawValue:)).map(KeyToken.cursor) ?? .noop
        case "overlay": self = value.flatMap(OverlayKind.init(rawValue:)).map(KeyToken.overlay) ?? .noop
        case "snippet": self = value.flatMap(UUID.init(uuidString:)).map(KeyToken.snippet) ?? .noop
        default: self = .noop  // unknown future token → forward-compat sink
        }
    }
}
