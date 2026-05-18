import SwiftUI

/// 30×30 icon tile with tinted gradient background. Used in settings toggle rows.
public struct MiniIcon: View {
    let symbolName: String
    let color: Color

    public init(_ symbolName: String, color: Color) {
        self.symbolName = symbolName
        self.color = color
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.16), color.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(color.opacity(0.22), lineWidth: 1)
                )
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(width: 30, height: 30)
    }
}
