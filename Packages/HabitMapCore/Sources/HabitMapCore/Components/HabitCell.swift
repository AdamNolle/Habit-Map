import SwiftUI

public struct HabitCell: View {
    let level: CellLevel
    let accent: Color
    let isToday: Bool
    let size: CGFloat

    public init(level: CellLevel, accent: Color, isToday: Bool, size: CGFloat) {
        self.level = level
        self.accent = accent
        self.isToday = isToday
        self.size = size
    }

    public var body: some View {
        Canvas { context, dim in
            let half = dim.width / 2.0
            let full = CGRect(origin: .zero, size: dim)

            let baseColor: Color = {
                switch level {
                case .future: return DesignTokens.Surface.future
                case .rest:   return DesignTokens.Surface.rest
                case .miss:   return DesignTokens.Surface.miss
                case .empty, .p25, .p50, .p75:
                    return DesignTokens.Surface.inactive
                case .p100:
                    return accent
                }
            }()
            context.fill(Path(full), with: .color(baseColor))

            switch level {
            case .p25:
                context.fill(Path(CGRect(x: half, y: 0, width: half, height: half)),
                             with: .color(accent))
            case .p50:
                context.fill(Path(CGRect(x: half, y: 0, width: half, height: dim.height)),
                             with: .color(accent))
            case .p75:
                context.fill(Path(CGRect(x: half, y: 0, width: half, height: dim.height)),
                             with: .color(accent))
                context.fill(Path(CGRect(x: 0, y: half, width: half, height: half)),
                             with: .color(accent))
            default:
                break
            }
        }
        .frame(width: size, height: size)
        .overlay(borderOverlay)
        .overlay(todayOutline)
        .drawingGroup()
    }

    @ViewBuilder private var borderOverlay: some View {
        switch level {
        case .future:
            Rectangle().stroke(DesignTokens.Surface.futureBorder,
                               style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        case .rest:
            Rectangle().stroke(DesignTokens.Surface.restBorder,
                               style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        default:
            EmptyView()
        }
    }

    @ViewBuilder private var todayOutline: some View {
        if isToday {
            Rectangle()
                .strokeBorder(accent, lineWidth: 2)
        }
    }
}
