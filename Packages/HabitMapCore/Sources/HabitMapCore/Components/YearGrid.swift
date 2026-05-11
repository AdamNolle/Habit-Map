import SwiftUI

public struct YearGrid: View {
    let habits: [Habit]
    let accent: Color
    let columns: Int
    let days: Int
    let onTap: (Date) -> Void

    public init(habits: [Habit], accent: Color, columns: Int = 20, days: Int = 365, onTap: @escaping (Date) -> Void) {
        self.habits = habits
        self.accent = accent
        self.columns = columns
        self.days = days
        self.onTap = onTap
    }

    public var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let rows = Int((Double(days) / Double(columns)).rounded(.up))

        GeometryReader { geo in
            let cellSize = max(2, (geo.size.width - CGFloat(columns - 1) * 2) / CGFloat(columns))
            VStack(spacing: 2) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<columns, id: \.self) { col in
                            let index = row * columns + col
                            if index < days {
                                let offset = days - 1 - index
                                let date = cal.date(byAdding: .day, value: -offset, to: today) ?? today
                                cell(for: date, size: cellSize, today: today, cal: cal)
                            } else {
                                Color.clear.frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
            }
        }
        .aspectRatio(CGFloat(columns) / CGFloat(rows), contentMode: .fit)
    }

    @ViewBuilder
    private func cell(for date: Date, size: CGFloat, today: Date, cal: Calendar) -> some View {
        let level = combinedLevel(on: date, today: today, cal: cal)
        let isToday = cal.isDate(date, inSameDayAs: today)
        HabitCell(level: level, accent: accent, isToday: isToday, size: size)
            .contentShape(Rectangle())
            .onTapGesture { onTap(date) }
            .accessibilityLabel(Self.dayLabel(date))
    }

    private func combinedLevel(on date: Date, today: Date, cal: Calendar) -> CellLevel {
        if date > today { return .future }
        let active = habits.filter { !$0.isArchived && !$0.isPaused }
        let scheduled = active.filter { $0.isScheduled(date) }
        if scheduled.isEmpty { return .empty }
        let avg = scheduled.map { $0.progressFraction(on: date) }.reduce(0, +) / Double(scheduled.count)
        return CellLevel.from(progress: avg)
    }

    private static func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}
