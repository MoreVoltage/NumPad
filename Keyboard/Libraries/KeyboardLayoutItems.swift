//
//  KeyboardLayoutItems.swift
//  Keyboard
//
//  Renders a custom KeyboardLayout into the extension's [[Item]] grid, reusing Items the existing
//  tap dispatch already handles (so haptics, sound, theming and insertion behave identically).
//  v1: standard keys — digits, operators, decimal separator, delete, return, space. Other tokens
//  (cursor/hide/tab/calc/snippet/pack/overlay) map to .blank and are skipped for now; per-key size,
//  colour, span and label overrides are follow-ups.
//

import UIKit

extension KeyboardLayoutRenderer {
    /// Builds the keyboard grid from a custom layout. Empty (all-blank) rows are dropped.
    static func items(for layout: KeyboardLayout, returnTitle: String) -> [[Item]] {
        layout.rows
            .map { row in row.compactMap { item(for: $0, returnTitle: returnTitle) } }
            .filter { !$0.isEmpty }
    }

    private static func item(for key: KeyDefinition, returnTitle: String) -> Item? {
        switch renderKind(for: key.primary) {
        case .insert(let text): return Item(title: text)
        case .separator:        return Item(title: ".")
        case .delete:           return Item(imageName: "back", style: .primary, isReversed: true)
        case .ret:              return Item(title: returnTitle, font: .text, style: .secondary, role: .returnKey)
        case .space:            return Item(title: String.space, font: .text, style: .secondary)
        case .blank:            return nil
        }
    }
}
