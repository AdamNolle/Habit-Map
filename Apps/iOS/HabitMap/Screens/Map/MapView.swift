import SwiftUI
import SwiftData
import HabitMapCore

struct MapView: View {
    @Query(filter: #Predicate<HabitPage> { !$0.isArchived },
           sort: \HabitPage.sortOrder) private var pages: [HabitPage]
    @EnvironmentObject private var repo: HabitRepository

    @State private var selectedPageID: UUID? = nil
    @State private var detailDate: Date?
    private let stats = StatsService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                PixelText("HEAT MAP", pixelSize: 4, color: accent)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.top, DesignTokens.Spacing.lg)
                    .accessibilityLabel("HEAT MAP")
                    .accessibilityAddTraits(.isHeader)

                filterChips
                    .padding(.horizontal, DesignTokens.Spacing.lg)

                StreakCard(consistency: stats.consistency(habits: filteredHabits),
                           currentStreak: stats.currentStreak(habits: filteredHabits),
                           bestStreak: stats.bestStreak(habits: filteredHabits),
                           accent: accent)
                    .padding(.horizontal, DesignTokens.Spacing.lg)

                YearGrid(habits: filteredHabits, accent: accent) { date in
                    detailDate = date
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)

                legend.padding(.horizontal, DesignTokens.Spacing.lg)
            }
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .background(DesignTokens.Surface.bg)
        .sheet(item: Binding(get: { detailDate.map { DateRef(date: $0) } },
                             set: { detailDate = $0?.date })) { ref in
            DayDetailSheet(date: ref.date, habits: filteredHabits, accent: accent)
                .environmentObject(repo)
        }
        .preferredColorScheme(.dark)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "ALL",
                           isSelected: selectedPageID == nil,
                           accent: DesignTokens.Accent.classicGreen) {
                    selectedPageID = nil
                }
                ForEach(pages) { page in
                    FilterChip(label: page.name,
                               isSelected: selectedPageID == page.id,
                               accent: page.accentColor) {
                        selectedPageID = page.id
                    }
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("LESS")
                .font(.system(.caption2, design: .monospaced).weight(.heavy))
                .tracking(1.0)
                .foregroundColor(DesignTokens.Surface.mutedText)
            HabitCell(level: .empty, accent: accent, isToday: false, size: 10)
            HabitCell(level: .p25, accent: accent, isToday: false, size: 10)
            HabitCell(level: .p50, accent: accent, isToday: false, size: 10)
            HabitCell(level: .p75, accent: accent, isToday: false, size: 10)
            HabitCell(level: .p100, accent: accent, isToday: false, size: 10)
            Text("MORE")
                .font(.system(.caption2, design: .monospaced).weight(.heavy))
                .tracking(1.0)
                .foregroundColor(DesignTokens.Surface.mutedText)
        }
    }

    private var accent: Color {
        if let id = selectedPageID, let page = pages.first(where: { $0.id == id }) {
            return page.accentColor
        }
        return DesignTokens.Accent.classicGreen
    }

    private var filteredHabits: [Habit] {
        if let id = selectedPageID, let page = pages.first(where: { $0.id == id }) {
            return (page.habits ?? []).filter { !$0.isArchived && !$0.isPaused }
        }
        return pages.flatMap { ($0.habits ?? []).filter { !$0.isArchived && !$0.isPaused } }
    }
}

private struct DateRef: Identifiable {
    let date: Date
    var id: Date { date }
}
