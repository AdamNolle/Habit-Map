import SwiftUI

public struct MasterHeatmapCard: View {
    let page: HabitPage
    let days: Int

    public init(page: HabitPage, days: Int = 30) {
        self.page = page
        self.days = days
    }

    public var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        VStack(alignment: .leading, spacing: 8) {
            PixelText("\(days) DAYS - \(page.name)",
                      pixelSize: 2,
                      color: page.accentColor)
            HStack(spacing: 2) {
                ForEach(0..<days, id: \.self) { offset in
                    let dayOffset = days - 1 - offset
                    let date = cal.date(byAdding: .day, value: -dayOffset, to: today) ?? today
                    let level = combinedLevel(on: date)
                    HabitCell(level: level,
                              accent: page.accentColor,
                              isToday: cal.isDate(date, inSameDayAs: today),
                              size: 10)
                }
            }
        }
        .padding(12)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(page.accentColor, lineWidth: 2))
    }

    private func combinedLevel(on date: Date) -> CellLevel {
        let active = (page.habits ?? []).filter { !$0.isArchived && !$0.isPaused }
        guard !active.isEmpty else { return .empty }
        if date > Date() { return .future }
        let avg = active.map { $0.progressFraction(on: date) }.reduce(0, +) / Double(active.count)
        return CellLevel.from(progress: avg)
    }
}
