import SwiftUI

/// Small-caps label with optional pulsing pip. Sans-serif by default for warmth,
/// mono variant for "terminal" surfaces.
public struct Eyebrow: View {
    let text: String
    let color: Color
    let showPip: Bool
    let mono: Bool
    let size: CGFloat

    public init(_ text: String,
                color: Color = DesignTokens.Surface.mutedText,
                showPip: Bool = false,
                mono: Bool = false,
                size: CGFloat = 11) {
        self.text = text
        self.color = color
        self.showPip = showPip
        self.mono = mono
        self.size = size
    }

    public var body: some View {
        HStack(spacing: 8) {
            if showPip { Pip(color: color) }
            Text(text.uppercased())
                .font(.custom(mono ? FontFamily.mono : FontFamily.sans, size: size))
                .fontWeight(.semibold)
                .tracking(mono ? size * 0.18 : size * 0.14)
                .foregroundColor(color)
        }
    }
}
