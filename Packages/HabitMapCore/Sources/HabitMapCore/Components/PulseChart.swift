import SwiftUI

/// 30-day consistency bar chart rendered on Canvas. Each bar represents one day's
/// completion fraction (0–1). Used in the InsightsView pulse card.
public struct PulseChart: View {
    let data: [Double]
    let accent: Color

    public init(data: [Double], accent: Color) {
        self.data = data
        self.accent = accent
    }

    public var body: some View {
        Canvas { context, size in
            let count = max(data.count, 1)
            let barW = (size.width - CGFloat(count - 1) * 2) / CGFloat(count)
            let baseY = size.height - 1

            // Baseline
            context.fill(
                Path(CGRect(x: 0, y: baseY, width: size.width, height: 1)),
                with: .color(Color.white.opacity(0.07))
            )

            for (i, value) in data.enumerated() {
                let x = CGFloat(i) * (barW + 2)
                let barH = max(2, value * (size.height - 4))
                let y = size.height - barH - 1
                let opacity = 0.25 + (value * 0.75)
                let barRect = CGRect(x: x, y: y, width: barW, height: barH)
                var path = Path()
                let r = min(barW * 0.35, 3.0)
                path.move(to: CGPoint(x: barRect.minX, y: barRect.maxY))
                path.addLine(to: CGPoint(x: barRect.minX, y: barRect.minY + r))
                path.addQuadCurve(to: CGPoint(x: barRect.minX + r, y: barRect.minY),
                                  control: CGPoint(x: barRect.minX, y: barRect.minY))
                path.addLine(to: CGPoint(x: barRect.maxX - r, y: barRect.minY))
                path.addQuadCurve(to: CGPoint(x: barRect.maxX, y: barRect.minY + r),
                                  control: CGPoint(x: barRect.maxX, y: barRect.minY))
                path.addLine(to: CGPoint(x: barRect.maxX, y: barRect.maxY))
                path.closeSubpath()
                context.fill(path, with: .color(accent.opacity(opacity)))
            }
        }
        .drawingGroup()
    }
}
