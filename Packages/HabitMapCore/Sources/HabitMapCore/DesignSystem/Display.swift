import SwiftUI

/// Instrument Serif hero title. The signature typeface of the app.
public struct Display: View {
    let text: String
    let size: Typography.Size
    let color: Color
    let italic: Bool

    public init(_ text: String,
                size: Typography.Size = .display2,
                color: Color = DesignTokens.Surface.fg(),
                italic: Bool = false) {
        self.text = text
        self.size = size
        self.color = color
        self.italic = italic
    }

    public var body: some View {
        Text(text)
            .font(.custom(italic ? FontFamily.serifItalic : FontFamily.serif, size: size.rawValue))
            .kerning(-0.6)
            .foregroundColor(color)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
    }
}
