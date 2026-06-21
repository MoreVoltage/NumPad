import SwiftUI

/// A single rounded key, reused by the editor's preview grid and the add-key palette.
/// Purely presentational — selection/drag/tap behaviour is attached by the parent.
struct KeyCapView: View {
    let label: String
    var isSelected: Bool = false
    var isDimmed: Bool = false

    var body: some View {
        Text(label)
            .font(.system(size: 18, weight: .medium, design: .rounded))
            .minimumScaleFactor(0.4)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .padding(.horizontal, 2)
            // `Color` is aliased to `UIColor.Custom` in this module (SharedExtensions.swift),
            // so SwiftUI's color must be fully qualified here and below.
            .background(RoundedRectangle(cornerRadius: 8).fill(SwiftUI.Color(.secondarySystemBackground)))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? SwiftUI.Color.accentColor : SwiftUI.Color(.separator),
                                  lineWidth: isSelected ? 2 : 0.5)
            )
            .foregroundColor(.primary)
            .opacity(isDimmed ? 0.4 : 1)
            .contentShape(Rectangle())
    }
}
