import SwiftUI

public struct PixelText: View {
    let text: String
    let pixelSize: CGFloat
    let color: Color
    let tracking: CGFloat

    public init(_ text: String, pixelSize: CGFloat, color: Color, tracking: CGFloat = 1) {
        self.text = text
        self.pixelSize = pixelSize
        self.color = color
        self.tracking = tracking
    }

    public var body: some View {
        HStack(alignment: .top, spacing: pixelSize * tracking) {
            ForEach(Array(text.uppercased().enumerated()), id: \.offset) { _, char in
                if char == " " {
                    Color.clear.frame(width: pixelSize * 2, height: pixelSize * 5)
                } else {
                    let rows = PixelFontGlyphs.rows(for: char) ?? PixelFontGlyphs.fallback
                    PixelGlyphView(rows: rows, pixelSize: pixelSize, color: color)
                }
            }
        }
        .drawingGroup()
    }
}

struct PixelGlyphView: View {
    let rows: [String]
    let pixelSize: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, _ in
            for (y, row) in rows.enumerated() {
                for (x, char) in row.enumerated() where char == "1" {
                    let rect = CGRect(x: CGFloat(x) * pixelSize,
                                      y: CGFloat(y) * pixelSize,
                                      width: pixelSize,
                                      height: pixelSize)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: CGFloat(rows[0].count) * pixelSize,
               height: CGFloat(rows.count) * pixelSize)
    }
}
