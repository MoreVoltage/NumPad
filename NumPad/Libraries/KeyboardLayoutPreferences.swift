//
//  KeyboardLayoutPreferences.swift
//  NumPad
//

import Foundation

enum QwertyLayoutMode: String, Codable, CaseIterable {
    case automatic
    case centered
    case split
    case compactLeft
    case compactRight
}

enum NumpadPlacement: String, Codable, CaseIterable {
    case automatic
    case center
    case left
    case right
    case fullWidth
}
