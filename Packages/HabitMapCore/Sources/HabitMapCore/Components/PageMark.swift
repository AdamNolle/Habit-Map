import SwiftUI

/// Tiny 2×2 pixel-grid mark in a page's accent color. Reads as a miniature
/// heatmap and replaces emoji in screen-level hero contexts.
public struct PageMark: View {
    let accent: Color
    let size: CGFloat

    public init(accent: Color, size: CGFloat = 14) {
        self.accent = accent
        self.size = size
    }

    public var body: some View {
        let cell = max(2, (size - 2) / 2)
        let gap: CGFloat = 2
        VStack(spacing: gap) {
            HStack(spacing: gap) {
                square(opacity: 0.45)
                square(opacity: 1.0)
            }
            HStack(spacing: gap) {
                square(opacity: 0.85)
                square(opacity: 0.25)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func square(opacity: Double) -> some View {
        let cell = max(2, (size - 2) / 2)
        Rectangle()
            .fill(accent.opacity(opacity))
            .frame(width: cell, height: cell)
    }
}
