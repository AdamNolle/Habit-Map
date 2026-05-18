import SwiftUI

/// Frosted-glass card container. Wraps content with `.ultraThinMaterial` +
/// 1px gradient highlight along the top + hairline border + soft shadow.
public struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let accent: Color?
    let content: () -> Content

    public init(cornerRadius: CGFloat = DesignTokens.Radius.lg,
                padding: CGFloat = 14,
                accent: Color? = nil,
                @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.accent = accent
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(accent ?? Color.white.opacity(0.06), lineWidth: 1)
            }
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [.white.opacity(0.06), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 1)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
    }
}
