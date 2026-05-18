import SwiftUI

public struct MasterHeatmapCard: View {
    let page: HabitPage
    let days: Int

    public init(page: HabitPage, days: Int = 28) {
        self.page = page
        self.days = days
    }

    public var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                PageMark(accent: page.accentColor, size: 18)
                Text("\(days) days · \(page.name.titleCased)")
                    .font(.custom(FontFamily.mono, size: 10))
                    .fontWeight(.semibold)
                    .tracking(10 * 0.14)
                    .foregroundColor(DesignTokens.Surface.mutedText)
                    .textCase(.uppercase)
            }
            HStack(spacing: 2) {
                ForEach(0..<days, id: \.self) { offset in
                    let dayOffset = days - 1 - offset
                    let date = cal.date(byAdding: .day, value: -dayOffset, to: today) ?? today
                    let level = combinedLevel(on: date)
                    HabitCell(level: level,
                              accent: page.accentColor,
                              isToday: cal.isDate(date, inSameDayAs: today),
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

    private func combinedLevel(on date: Date) -> CellLevel {
        let active = (page.habits ?? []).filter { !$0.isArchived && !$0.isPaused }
        guard !active.isEmpty else { return .empty }
        if date > Date() { return .future }
        let scheduled = active.filter { $0.isScheduled(date) }
        guard !scheduled.isEmpty else { return .rest }
        let avg = scheduled.map { $0.progressFraction(on: date) }.reduce(0, +) / Double(scheduled.count)
        return CellLevel.from(progress: avg)
    }
}
