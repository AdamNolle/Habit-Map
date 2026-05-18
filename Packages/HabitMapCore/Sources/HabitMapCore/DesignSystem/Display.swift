import SwiftUI

/// Instrument Serif hero title. The signature typeface of the app.
public struct Display: View {
    let text: String
    let rawSize: CGFloat
    let color: Color
    let italic: Bool

    public init(_ text: String,
                size: Typography.Size = .display2,
                color: Color = DesignTokens.Surface.fg(),
                italic: Bool = false) {
        self.text = text
        self.rawSize = size.rawValue
        self.color = color
        self.italic = italic
    }

    public init(_ text: String,
                size: CGFloat,
                color: Color = DesignTokens.Surface.fg(),
                italic: Bool = false) {
        self.text = text
        self.rawSize = size
        self.color = color
        self.italic = italic
    }

    public var body: some View {
        Text(text)
            .font(.custom(italic ? FontFamily.serifItalic : FontFamily.serif, size: rawSize))
            .kerning(-0.6)
            .foregroundColor(color)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
    }
}
