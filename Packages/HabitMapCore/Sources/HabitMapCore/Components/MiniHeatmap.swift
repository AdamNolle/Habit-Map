import SwiftUI

public struct MiniHeatmap: View {
    let habit: Habit
    let cellSize: CGFloat
    let columns: Int
    let rows: Int

    public init(habit: Habit, cellSize: CGFloat = 6, columns: Int = 15, rows: Int = 2) {
        self.habit = habit
        self.cellSize = cellSize
        self.columns = columns
        self.rows = rows
    }

    public var body: some View {
        let total = columns * rows
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        VStack(spacing: 1) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        let dayOffset = total - 1 - index
                        let date = cal.date(byAdding: .day, value: -dayOffset, to: today) ?? today
                        let level = habit.cellLevel(on: date)
                        let isToday = cal.isDate(date, inSameDayAs: today)
                        HabitCell(level: level,
                                  accent: habit.accentColor,
                                  isToday: isToday,
                                  size: cellSize)
                    }
                }
            }
        }
    }
}
