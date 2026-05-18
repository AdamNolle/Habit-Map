import SwiftUI

/// Animated background of 3 large blurred color blobs drifting slowly.
/// Provides depth + life behind screen content without dominating it.
public struct LavaBackground: View {
    let accent: Color
    let secondary: Color

    public init(accent: Color = DesignTokens.Accent.classicGreen,
                secondary: Color = DesignTokens.Semantic.ai) {
        self.accent = accent
        self.secondary = secondary
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                drawBlob(ctx: &ctx, color: accent, opacity: 0.10, size: size,
                         phase: t / 44.0, baseX: -0.10, baseY: -0.22, radius: size.width * 0.45)
                drawBlob(ctx: &ctx, color: secondary, opacity: 0.06, size: size,
                         phase: t / 56.0, baseX: 1.15, baseY: 1.20, radius: size.width * 0.40)
                drawBlob(ctx: &ctx, color: accent, opacity: 0.05, size: size,
                         phase: t / 68.0, baseX: 0.5, baseY: 0.5, radius: size.width * 0.30)
            }
            .blur(radius: 72)
            .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }

    private func drawBlob(ctx: inout GraphicsContext, color: Color, opacity: Double,
                          size: CGSize, phase: Double, baseX: Double, baseY: Double, radius: CGFloat) {
        let driftX = sin(phase * 2.0 * .pi) * 0.25
        let driftY = cos(phase * 2.0 * .pi * 0.7) * 0.25
        let x = (baseX + driftX) * size.width
        let y = (baseY + driftY) * size.height
        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
    }
}
