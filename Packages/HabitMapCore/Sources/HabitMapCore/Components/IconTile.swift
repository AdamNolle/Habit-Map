import SwiftUI

/// Rounded gradient tile with SF Symbol inside. Used in habit rows.
/// When `done`, shows accent gradient + glow; when undone, subtle muted tile.
public struct IconTile: View {
    let symbol: String
    let accent: Color
    let done: Bool
    let size: CGFloat

    public init(symbol: String, accent: Color, done: Bool, size: CGFloat = 32) {
        self.symbol = symbol
        self.accent = accent
        self.done = done
        self.size = size
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(fillStyle)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundColor(done ? Color.black.opacity(0.85) : DesignTokens.Surface.mutedText)
            )
            .frame(width: size, height: size)
            .shadow(color: done ? accent.opacity(0.45) : .clear,
                    radius: done ? 10 : 0, y: done ? 4 : 0)
    }

    private var fillStyle: AnyShapeStyle {
        if done {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [accent.lighter(by: 0.1), accent, accent.darker(by: 0.08)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(DesignTokens.Surface.tint1())
    }

    private var borderColor: Color {
        done ? accent.darker(by: 0.25) : Color.white.opacity(0.055)
    }
}
