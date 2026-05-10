import SwiftUI

public struct PixelIcon: View {
    let name: PixelIconName
    let color: Color
    let size: CGFloat

    public init(_ name: PixelIconName, color: Color, size: CGFloat) {
        self.name = name
        self.color = color
        self.size = size
    }

    public var body: some View {
        Canvas { context, canvas in
            let scale = canvas.width / 24.0
            for layer in name.layers {
                let layerColor = color(for: layer.role)
                for rect in layer.rects {
                    let scaled = CGRect(x: rect.minX * scale,
                                        y: rect.minY * scale,
                                        width: rect.width * scale,
                                        height: rect.height * scale)
                    context.fill(Path(scaled), with: .color(layerColor))
                }
            }
        }
        .frame(width: size, height: size)
        .drawingGroup()
    }

    private func color(for role: LayerRole) -> Color {
        switch role {
        case .base: return color
        case .highlight: return color.lighter(by: 0.25)
        case .shadow: return Color.black
        }
    }
}
