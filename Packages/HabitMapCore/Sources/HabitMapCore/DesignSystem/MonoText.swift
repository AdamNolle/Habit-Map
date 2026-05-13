import SwiftUI

/// Monospaced (SF Mono) text view with consistent typography scale + tracking.
/// Use this for any readable body / button / row text in the app. PixelText
/// stays for pixel-art screen-level headers only.
public struct MonoText: View {
    let text: String
    let size: Typography.Size
    let weight: Typography.Weight
    let color: Color

    public init(_ text: String,
                size: Typography.Size = .body,
                weight: Typography.Weight = .heavy,
                color: Color = .white) {
        self.text = text
        self.size = size
        self.weight = weight
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(.system(size: size.rawValue, weight: weight.swiftUI, design: .monospaced))
            .tracking(size.tracking)
            .foregroundColor(color)
    }
}

public extension MonoText {
    /// Convenience for ALL-CAPS labels (settings rows, button labels).
    static func label(_ text: String, color: Color = DesignTokens.Surface.mutedText) -> MonoText {
        MonoText(text.uppercased(), size: .footnote, weight: .heavy, color: color)
    }

    /// Convenience for action-button labels (primary, secondary).
    static func action(_ text: String, color: Color) -> MonoText {
        MonoText(text.uppercased(), size: .body, weight: .heavy, color: color)
    }
}
