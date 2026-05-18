import SwiftUI

/// JetBrains Mono numeric display with tabular figures + tight letter-spacing.
/// Use for: percentages, streak counters, reps, all stat tiles.
public struct MonoNum: View {
    let text: String
    let size: CGFloat
    let weight: Font.Weight
    let color: Color
    let glow: Bool

    public init(_ text: String,
                size: CGFloat = 36,
                weight: Font.Weight = .bold,
                color: Color = DesignTokens.Accent.classicGreen,
                glow: Bool = false) {
        self.text = text
        self.size = size
        self.weight = weight
        self.color = color
        self.glow = glow
    }

    public var body: some View {
        Text(text)
            .font(.custom(FontFamily.mono, size: size))
            .fontWeight(weight)
            .monospacedDigit()
            .kerning(-0.4)
            .foregroundColor(color)
            .shadow(color: glow ? color.opacity(0.4) : .clear, radius: glow ? 8 : 0)
    }
}
