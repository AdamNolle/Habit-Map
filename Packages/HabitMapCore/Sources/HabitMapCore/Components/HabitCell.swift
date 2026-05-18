import SwiftUI

/// Quadrant-fill pixel cell. Refined v5: rounded corners, soft glow on today,
/// gradient sheen on full p100 cells.
public struct HabitCell: View {
    let level: CellLevel
    let accent: Color
    let isToday: Bool
    let size: CGFloat
    let radius: CGFloat

    public init(level: CellLevel, accent: Color, isToday: Bool, size: CGFloat, radius: CGFloat = 0) {
        self.level = level
        self.accent = accent
        self.isToday = isToday
        self.size = size
        self.radius = radius
    }

    public var body: some View {
        let corner = effectiveRadius
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(baseColor)
            quadrantOverlay(corner: corner)
            border
        }
        .frame(width: size, height: size)
        .overlay(todayOutline)
        .shadow(color: glowColor, radius: glowRadius)
    }

    private var effectiveRadius: CGFloat {
        if radius > 0 { return radius }
        return max(1, size * 0.18)
    }

    private var baseColor: Color {
        switch level {
        case .future: return DesignTokens.Surface.future
        case .rest:   return DesignTokens.Surface.rest
        case .miss:   return DesignTokens.Surface.miss
        case .empty, .p25, .p50, .p75:
            return DesignTokens.Surface.inactive
        case .p100:
            return accent
        }
    }

    private var glowColor: Color {
        guard isToday && (level == .p100 || level == .p75) else { return .clear }
        return accent.opacity(0.5)
    }

    private var glowRadius: CGFloat {
        glowColor == .clear ? 0 : size * 0.25
    }

    @ViewBuilder
    private func quadrantOverlay(corner: CGFloat) -> some View {
        Canvas { context, dim in
            let half = dim.width / 2.0
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
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    @ViewBuilder private var border: some View {
        switch level {
        case .future:
            RoundedRectangle(cornerRadius: effectiveRadius, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundColor(DesignTokens.Surface.futureBorder)
        case .rest:
            RoundedRectangle(cornerRadius: effectiveRadius, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundColor(DesignTokens.Surface.restBorder)
        default:
            EmptyView()
        }
    }

    @ViewBuilder private var todayOutline: some View {
        if isToday {
            RoundedRectangle(cornerRadius: effectiveRadius, style: .continuous)
                .strokeBorder(accent, lineWidth: 1.5)
        }
    }
}
