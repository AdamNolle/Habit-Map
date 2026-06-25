import SwiftUI

/// Mini line sparkline with area fill. Used in per-page stat rows in InsightsView.
public struct Sparkline: View {
    let data: [Double]
    /// Non-nil when initialized from an optional series; `nil` entries render as gaps, not misses.
    let optionalData: [Double?]?
    let accent: Color

    public init(data: [Double], accent: Color) {
        self.data = data
        self.optionalData = nil
        self.accent = accent
    }

    /// Optional series: `nil` days (e.g. before a habit's `activeSince`, or unscheduled) render as
    /// gaps rather than dips to zero. A fully non-nil array renders identically to `init(data:)`.
    public init(data: [Double?], accent: Color) {
        self.data = []
        self.optionalData = data
        self.accent = accent
    }

    public var body: some View {
        Canvas { context, size in
            // Optional series: draw each contiguous run of non-nil samples as a line+area segment
            // and skip nil days (gaps). This path is only taken via init(data: [Double?]); the
            // existing [Double] path below is left byte-identical so snapshots stay stable.
            if let optionalData {
                guard optionalData.count > 1 else { return }
                let present = optionalData.compactMap { $0 }
                guard !present.isEmpty else { return }
                let maxVal = present.max() ?? 1
                let minVal = present.min() ?? 0
                let range = max(maxVal - minVal, 0.001)
                let stepX = size.width / CGFloat(optionalData.count - 1)
                func pointAt(_ i: Int, _ v: Double) -> CGPoint {
                    let x = CGFloat(i) * stepX
                    let normalized = (v - minVal) / range
                    let y = size.height - (CGFloat(normalized) * (size.height - 2)) - 1
                    return CGPoint(x: x, y: y)
                }
                var i = 0
                while i < optionalData.count {
                    guard let startVal = optionalData[i] else { i += 1; continue }
                    let runStart = i
                    var runEnd = i
                    var linePath = Path()
                    linePath.move(to: pointAt(i, startVal))
                    var j = i + 1
                    while j < optionalData.count, let v = optionalData[j] {
                        linePath.addLine(to: pointAt(j, v))
                        runEnd = j
                        j += 1
                    }
                    if runEnd > runStart {
                        context.stroke(linePath, with: .color(accent), lineWidth: 1.5)
                        var areaPath = linePath
                        areaPath.addLine(to: CGPoint(x: CGFloat(runEnd) * stepX, y: size.height))
                        areaPath.addLine(to: CGPoint(x: CGFloat(runStart) * stepX, y: size.height))
                        areaPath.closeSubpath()
                        context.fill(areaPath, with: .color(accent.opacity(0.12)))
                    }
                    i = j
                }
                return
            }
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
