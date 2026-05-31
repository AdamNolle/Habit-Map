import SwiftUI

public struct MasterHeatmapCard: View {
    let page: HabitPage
    let days: Int

    private let title: String
    private let cells: [Cell]

    private struct Cell: Identifiable {
        let id: Int
        let level: CellLevel
        let isToday: Bool
    }

    public init(page: HabitPage, days: Int = 28) {
        self.page = page
        self.days = days
        self.title = "\(days) days · \(page.name.titleCased)"

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let now = Date()
        let active = (page.habits ?? []).filter { !$0.isArchived && !$0.isPaused }
        self.cells = (0..<days).map { offset in
            let dayOffset = days - 1 - offset
            let date = cal.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            return Cell(id: offset,
                        level: Self.combinedLevel(on: date, active: active, now: now, cal: cal),
                        isToday: cal.isDate(date, inSameDayAs: today))
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                PageMark(accent: page.accentColor, size: 18)
                Text(title)
                    .font(.custom(FontFamily.mono, size: 10))
                    .fontWeight(.semibold)
                    .tracking(10 * 0.14)
                    .foregroundColor(DesignTokens.Surface.mutedText)
                    .textCase(.uppercase)
            }
            HStack(spacing: 2) {
                ForEach(cells) { cell in
                    HabitCell(level: cell.level,
                              accent: page.accentColor,
                              isToday: cell.isToday,
                              size: 10,
                              radius: 2)
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        }
        .overlay(alignment: .top) {
            LinearGradient(colors: [.white.opacity(0.06), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 1)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                .allowsHitTesting(false)
        }
    }

    private static func combinedLevel(on date: Date, active: [Habit], now: Date, cal: Calendar) -> CellLevel {
        guard !active.isEmpty else { return .empty }
        if date > now { return .future }
        let scheduled = active.filter { $0.isScheduled(date) }
        guard !scheduled.isEmpty else { return .rest }
        let avg = scheduled.map { $0.progressFraction(on: date) }.reduce(0, +) / Double(scheduled.count)
        return CellLevel.from(progress: avg)
    }
}
