import SwiftUI

/// GitHub-style calendar heatmap: 7 rows × N weeks, ending today.
/// Replaces YearGrid in the MapView for the atlas layout.
public struct CalendarHeatmap: View {
    let habits: [Habit]
    let accent: Color
    let weeks: Int
    let cellSize: CGFloat
    let onTapDay: ((Date) -> Void)?

    private let gap: CGFloat = 2
    private let cal = Calendar.current

    public init(habits: [Habit],
                accent: Color,
                weeks: Int = 36,
                cellSize: CGFloat = 8,
                onTapDay: ((Date) -> Void)? = nil) {
        self.habits = habits
        self.accent = accent
        self.weeks = weeks
        self.cellSize = cellSize
        self.onTapDay = onTapDay
    }

    private var days: [Date] {
        let today = cal.startOfDay(for: Date())
        let totalDays = weeks * 7
        return (0..<totalDays).compactMap {
            cal.date(byAdding: .day, value: -(totalDays - 1 - $0), to: today)
        }
    }

    private func level(for date: Date) -> CellLevel {
        guard date <= Date() else { return .future }
        let active = habits.filter { !$0.isArchived && !$0.isPaused }
        guard !active.isEmpty else { return .empty }
        let scheduled = active.filter { $0.isScheduled(date) }
        guard !scheduled.isEmpty else { return .rest }
        let avg = scheduled.map { $0.progressFraction(on: date) }.reduce(0, +) / Double(scheduled.count)
        return CellLevel.from(progress: avg)
    }

    public var body: some View {
        let today = cal.startOfDay(for: Date())
        let step = cellSize + gap
        let totalWidth = CGFloat(weeks) * step - gap

        Canvas { context, _ in
            for (i, date) in days.enumerated() {
                let col = i / 7
                let row = i % 7
                let x = CGFloat(col) * step
                let y = CGFloat(row) * step
                let lvl = level(for: date)
                let isToday = cal.isDate(date, inSameDayAs: today)
                let cellColor = cellColor(for: lvl, isToday: isToday)
                let r = max(1, cellSize * 0.25)
                let rect = CGRect(x: x, y: y, width: cellSize, height: cellSize)
                let path = Path(roundedRect: rect, cornerRadius: r)
                context.fill(path, with: .color(cellColor))
                if isToday {
                    context.stroke(path, with: .color(accent), lineWidth: 1)
                }
            }
        }
        .frame(width: totalWidth, height: CGFloat(7) * step - gap)
        .gesture(
            onTapDay != nil ? SpatialTapGesture()
                .onEnded { value in
                    let col = Int(value.location.x / step)
                    let row = Int(value.location.y / step)
                    let i = col * 7 + row
                    guard i >= 0 && i < days.count else { return }
                    onTapDay?(days[i])
                } : nil
        )
    }

    private func cellColor(for level: CellLevel, isToday: Bool) -> Color {
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
