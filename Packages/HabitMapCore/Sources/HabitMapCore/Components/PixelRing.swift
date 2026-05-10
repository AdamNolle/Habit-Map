import SwiftUI

public struct PixelRing: View {
    let filledSegments: Int
    let accent: Color

    public init(filledSegments: Int, accent: Color) {
        self.filledSegments = min(max(filledSegments, 0), 12)
        self.accent = accent
    }

    /// Maps a 0..1 fraction to a count of filled segments (0..12).
    /// 0.0 → 0, 0.24 → 3, 0.50 → 6, 0.99 → 12, 1.0 → 12.
    public static func segments(for percent: Double) -> Int {
        if percent >= 1.0 { return 12 }
        if percent <= 0.0 { return 0 }
        return min(Int((percent * 12.0).rounded()), 12)
    }

    public var body: some View {
        Canvas { context, dim in
            let scale = dim.width / 32.0
            for px in PixelRing.pixels {
                let color = px.segment < filledSegments
                    ? accent
                    : DesignTokens.Surface.inactive
                let rect = CGRect(x: CGFloat(px.x) * scale,
                                  y: CGFloat(px.y) * scale,
                                  width: scale,
                                  height: scale)
                context.fill(Path(rect), with: .color(color))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .drawingGroup()
    }

    struct RingPixel { let x: Int; let y: Int; let segment: Int }

    /// 32×32 grid; pixels in the ring annulus; segment 0..11 clockwise from 12 o'clock.
    static let pixels: [RingPixel] = {
        var result: [RingPixel] = []
        let center = 16.0
        let innerR = 9.0
        let outerR = 15.0
        for y in 0..<32 {
            for x in 0..<32 {
                let dx = Double(x) + 0.5 - center
                let dy = Double(y) + 0.5 - center
                let r = (dx * dx + dy * dy).squareRoot()
                guard r >= innerR && r <= outerR else { continue }
                var angle = atan2(dx, -dy)
                if angle < 0 { angle += 2 * .pi }
                let segment = Int((angle / (2 * .pi)) * 12.0) % 12
                result.append(RingPixel(x: x, y: y, segment: segment))
            }
        }
        return result
    }()
}
