import SwiftUI

/// Animated background of 3 large blurred colour blobs drifting slowly.
/// Provides depth + life behind screen content without dominating it.
///
/// Performance: the drift periods are 44–68s, so the motion reads identically at
/// 12fps as at 30fps while doing ~60% fewer Canvas repaints. Pass `isPaused` to
/// freeze it to a single deterministic frame — used when the view is off-screen
/// (no point animating pixels nobody sees) and for stable snapshot rendering.
public struct LavaBackground: View {
    let accent: Color
    let secondary: Color
    var isPaused: Bool

    public init(accent: Color = DesignTokens.Accent.classicGreen,
                secondary: Color = DesignTokens.Semantic.ai,
                isPaused: Bool = false) {
        self.accent = accent
        self.secondary = secondary
        self.isPaused = isPaused
    }

    public var body: some View {
        Group {
            if isPaused {
                // Deterministic static frame — no TimelineView, no per-frame work.
                canvas(t: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { context in
                    canvas(t: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func canvas(t: Double) -> some View {
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
