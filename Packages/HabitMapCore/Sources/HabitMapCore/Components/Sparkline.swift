import SwiftUI

/// Mini line sparkline with area fill. Used in per-page stat rows in InsightsView.
public struct Sparkline: View {
    let data: [Double]
    let accent: Color

    public init(data: [Double], accent: Color) {
        self.data = data
        self.accent = accent
    }

    public var body: some View {
        Canvas { context, size in
            guard data.count > 1 else { return }
            let maxVal = data.max() ?? 1
            let minVal = data.min() ?? 0
            let range = max(maxVal - minVal, 0.001)
            let stepX = size.width / CGFloat(data.count - 1)

            func pointAt(_ i: Int) -> CGPoint {
                let x = CGFloat(i) * stepX
                let normalized = (data[i] - minVal) / range
                let y = size.height - (CGFloat(normalized) * (size.height - 2)) - 1
                return CGPoint(x: x, y: y)
            }

            var linePath = Path()
            linePath.move(to: pointAt(0))
            for i in 1..<data.count {
                linePath.addLine(to: pointAt(i))
            }
            context.stroke(linePath, with: .color(accent), lineWidth: 1.5)

            var areaPath = linePath
            areaPath.addLine(to: CGPoint(x: size.width, y: size.height))
            areaPath.addLine(to: CGPoint(x: 0, y: size.height))
            areaPath.closeSubpath()
            context.fill(areaPath, with: .color(accent.opacity(0.12)))
        }
        .drawingGroup()
    }
}
