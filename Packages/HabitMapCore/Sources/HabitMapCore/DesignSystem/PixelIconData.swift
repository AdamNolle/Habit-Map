import Foundation

public enum PixelIconName: String, CaseIterable, Sendable {
    case home, grid, plus, chart, gear
}

public enum LayerRole: Sendable {
    case base, highlight, shadow
}

public struct PixelIconLayer: Sendable {
    public let rects: [CGRect]
    public let role: LayerRole
    public init(rects: [CGRect], role: LayerRole) {
        self.rects = rects
        self.role = role
    }
}

extension PixelIconName {
    /// 24×24 grid. Coordinates are integer pixel positions.
    public var layers: [PixelIconLayer] {
        switch self {
        case .home:
            return [
                PixelIconLayer(rects: [
                    CGRect(x: 11, y: 4, width: 2, height: 1),
                    CGRect(x: 9, y: 5, width: 2, height: 1),  CGRect(x: 13, y: 5, width: 2, height: 1),
                    CGRect(x: 7, y: 6, width: 2, height: 1),  CGRect(x: 15, y: 6, width: 2, height: 1),
                    CGRect(x: 5, y: 7, width: 2, height: 1),  CGRect(x: 17, y: 7, width: 2, height: 1),
                    CGRect(x: 3, y: 8, width: 2, height: 1),  CGRect(x: 19, y: 8, width: 2, height: 1),
                    CGRect(x: 5, y: 9, width: 1, height: 11),
                    CGRect(x: 18, y: 9, width: 1, height: 11),
                    CGRect(x: 5, y: 19, width: 14, height: 1),
                    CGRect(x: 10, y: 13, width: 4, height: 7)
                ], role: .base)
            ]
        case .grid:
            return [
                PixelIconLayer(rects: [
                    CGRect(x: 3, y: 3, width: 5, height: 5),
                    CGRect(x: 10, y: 3, width: 5, height: 5),
                    CGRect(x: 17, y: 3, width: 4, height: 5),
                    CGRect(x: 3, y: 10, width: 5, height: 5),
                    CGRect(x: 10, y: 10, width: 5, height: 5),
                    CGRect(x: 17, y: 10, width: 4, height: 5),
                    CGRect(x: 3, y: 17, width: 5, height: 4),
                    CGRect(x: 10, y: 17, width: 5, height: 4),
                    CGRect(x: 17, y: 17, width: 4, height: 4)
                ], role: .base)
            ]
        case .plus:
            return [
                PixelIconLayer(rects: [
                    CGRect(x: 4, y: 10, width: 16, height: 4),
                    CGRect(x: 10, y: 4, width: 4, height: 16)
                ], role: .base)
            ]
        case .chart:
            return [
                PixelIconLayer(rects: [
                    CGRect(x: 4, y: 4, width: 1, height: 16),
                    CGRect(x: 4, y: 19, width: 16, height: 1),
                    CGRect(x: 6, y: 15, width: 3, height: 4),
                    CGRect(x: 10, y: 12, width: 3, height: 7),
                    CGRect(x: 14, y: 9, width: 3, height: 10),
                    CGRect(x: 18, y: 6, width: 2, height: 13)
                ], role: .base)
            ]
        case .gear:
            return [
                PixelIconLayer(rects: [
                    // outer 8 teeth
                    CGRect(x: 10, y: 2, width: 4, height: 3),
                    CGRect(x: 10, y: 19, width: 4, height: 3),
                    CGRect(x: 2, y: 10, width: 3, height: 4),
                    CGRect(x: 19, y: 10, width: 3, height: 4),
                    CGRect(x: 4, y: 4, width: 3, height: 3),
                    CGRect(x: 17, y: 4, width: 3, height: 3),
                    CGRect(x: 4, y: 17, width: 3, height: 3),
                    CGRect(x: 17, y: 17, width: 3, height: 3),
                    // gear body
                    CGRect(x: 7, y: 5, width: 10, height: 14),
                    CGRect(x: 5, y: 7, width: 14, height: 10)
                ], role: .base),
                PixelIconLayer(rects: [
                    CGRect(x: 10, y: 10, width: 4, height: 4)
                ], role: .shadow)
            ]
        }
    }
}
