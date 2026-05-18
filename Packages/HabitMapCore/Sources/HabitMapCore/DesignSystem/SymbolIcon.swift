import SwiftUI

/// SF Symbol wrapper with consistent weight + scale + color across the app.
public struct SymbolIcon: View {
    let name: String
    let size: CGFloat
    let weight: Font.Weight
    let color: Color

    public init(_ name: String,
                size: CGFloat = 16,
                weight: Font.Weight = .semibold,
                color: Color = DesignTokens.Surface.fg()) {
        self.name = name
        self.size = size
        self.weight = weight
        self.color = color
    }

    public var body: some View {
        Image(systemName: name)
            .font(.system(size: size, weight: weight))
            .foregroundColor(color)
            .symbolRenderingMode(.hierarchical)
    }
}
