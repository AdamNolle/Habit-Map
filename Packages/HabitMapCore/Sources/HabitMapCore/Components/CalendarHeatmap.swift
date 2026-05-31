import SwiftUI

/// GitHub-style calendar heatmap: 7 rows × N weeks, ending today.
/// Replaces YearGrid in the MapView for the atlas layout.
///
/// Performance: every cell's level/colour/rect is resolved **once** in `init`
/// (i.e. when the habit data changes), not inside the `Canvas` draw closure.
/// Previously each of the up-to-252 cells re-ran habit filtering + scheduling +
/// progress math on every repaint (scroll, animation); now the draw loop just
/// fills precomputed rects.
public struct CalendarHeatmap: View {
    let accent: Color
    let onTapDay: ((Date) -> Void)?

    private let cells: [Cell]
    private let dates: [Date]
    private let step: CGFloat
    private let totalWidth: CGFloat
    private let totalHeight: CGFloat

    private struct Cell {
        let rect: CGRect
        let cornerRadius: CGFloat
        let color: Color
        let isToday: Bool
    }

    public init(habits: [Habit],
                accent: Color,
                weeks: Int = 36,
                cellSize: CGFloat = 8,
                onTapDay: ((Date) -> Void)? = nil) {
        self.accent = accent
        self.onTapDay = onTapDay

        let gap: CGFloat = 2
        let step = cellSize + gap
        self.step = step
        self.totalWidth = CGFloat(weeks) * step - gap
        self.totalHeight = CGFloat(7) * step - gap

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let now = Date()
        let totalDays = weeks * 7
        let dates = (0..<totalDays).compactMap {
            cal.date(byAdding: .day, value: -(totalDays - 1 - $0), to: today)
        }
        self.dates = dates

        let active = habits.filter { !$0.isArchived && !$0.isPaused }
        let radius = max(1, cellSize * 0.25)
        self.cells = dates.enumerated().map { i, date in
            let col = i / 7
            let row = i % 7
            let rect = CGRect(x: CGFloat(col) * step, y: CGFloat(row) * step,
                              width: cellSize, height: cellSize)
            let level = Self.level(for: date, active: active, now: now, cal: cal)
            let isToday = cal.isDate(date, inSameDayAs: today)
            return Cell(rect: rect, cornerRadius: radius,
                        color: Self.cellColor(for: level, isToday: isToday, accent: accent),
                        isToday: isToday)
        }
    }

    private static func level(for date: Date, active: [Habit], now: Date, cal: Calendar) -> CellLevel {
        guard date <= now else { return .future }
        guard !active.isEmpty else { return .empty }
        let scheduled = active.filter { $0.isScheduled(date) }
        guard !scheduled.isEmpty else { return .rest }
        let avg = scheduled.map { $0.progressFraction(on: date) }.reduce(0, +) / Double(scheduled.count)
        return CellLevel.from(progress: avg)
    }

    public var body: some View {
        Canvas { context, _ in
            for cell in cells {
                let path = Path(roundedRect: cell.rect, cornerRadius: cell.cornerRadius)
                context.fill(path, with: .color(cell.color))
                if cell.isToday {
                    context.stroke(path, with: .color(accent), lineWidth: 1)
                }
            }
        }
        .frame(width: totalWidth, height: totalHeight)
        .gesture(
            onTapDay != nil ? SpatialTapGesture()
                .onEnded { value in
                    let col = Int(value.location.x / step)
                    let row = Int(value.location.y / step)
                    let i = col * 7 + row
                    guard i >= 0 && i < dates.count else { return }
                    onTapDay?(dates[i])
                } : nil
        )
    }

    private static func cellColor(for level: CellLevel, isToday: Bool, accent: Color) -> Color {
        switch level {
        case .future: return DesignTokens.Surface.inactive.opacity(0.35)
        case .rest:   return DesignTokens.Surface.inactive.opacity(0.5)
        case .miss:   return DesignTokens.Semantic.danger.opacity(0.35)
        case .empty:  return DesignTokens.Surface.inactive
        case .p25:    return accent.opacity(0.25)
        case .p50:    return accent.opacity(0.50)
        case .p75:    return accent.opacity(0.75)
        case .p100:   return accent
        }
    }
}
