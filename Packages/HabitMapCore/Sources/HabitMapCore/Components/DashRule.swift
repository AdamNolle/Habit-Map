import SwiftUI

/// Dashed hairline divider with accent stops on either end.
public struct DashRule: View {
    let accent: Color

    public init(accent: Color = DesignTokens.Accent.classicGreen) {
        self.accent = accent
    }

    public var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accent.opacity(0.45))
                .frame(width: 1, height: 6)
            Rectangle()
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundColor(DesignTokens.Surface.line())
                .frame(height: 1)
            Rectangle()
                .fill(accent.opacity(0.45))
                .frame(width: 1, height: 6)
        }
    }
}
