import SwiftUI
import SwiftData
import HabitMapCore

struct MapView: View {
    @Query(filter: #Predicate<HabitPage> { !$0.isArchived },
           sort: \HabitPage.sortOrder) private var pages: [HabitPage]
    @EnvironmentObject private var repo: HabitRepository
    @EnvironmentObject private var haptics: Haptics

    @State private var selectedPageID: UUID? = nil
    @State private var detailDate: Date?
    private let stats = StatsService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Masthead
                Text("Habit Map · No.07 · Atlas")
                    .font(.custom(FontFamily.mono, size: 10))
                    .fontWeight(.semibold)
                    .tracking(10 * 0.22)
                    .textCase(.uppercase)
                    .foregroundColor(DesignTokens.Surface.mutedText)

                // Hero
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(
                        "\(HabitDateLabel.today()) · Last 252 days",
                        color: accent,
                        showPip: true
                    )
                    HStack(alignment: .lastTextBaseline, spacing: 12) {
                        Display("The atlas", size: 50, italic: true)
                        Display("—heat", size: 28, color: accent, italic: true)
                    }
                    .padding(.top, 14)
                    Text("Every habit, every day. \(Int(stats.consistency(habits: filteredHabits, window: 30) * 100))% consistency.")
                        .font(.custom(FontFamily.sans, size: 14))
                        .italic()
                        .foregroundColor(DesignTokens.Surface.mutedText)
                        .padding(.top, 10)
                }

                DashRule(accent: accent)

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Chip(label: "All habits", isSelected: selectedPageID == nil,
                             accent: DesignTokens.Accent.classicGreen) {
                            haptics.filterChange()
                            selectedPageID = nil
                        }
                        ForEach(pages) { page in
                            Chip(label: page.name.titleCased,
                                 isSelected: selectedPageID == page.id,
                                 accent: page.accentColor) {
                                haptics.filterChange()
                                selectedPageID = page.id
                            }
                        }
                    }
                }

                // 3-col ledger
                ledgerCard

                // Calendar atlas
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Calendar", action: "36 weeks")
                    GlassCard(cornerRadius: 18, padding: 16) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            CalendarHeatmap(
                                habits: filteredHabits,
                                accent: accent,
                                weeks: 36,
                                cellSize: 8
                            ) { date in
                                detailDate = date
                            }
                        }
                    }
                }

                // Intensity legend
                HStack(spacing: 8) {
                    Text("Less")
                        .font(.custom(FontFamily.sans, size: 11))
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Surface.mutedText)
                    ForEach([CellLevel.empty, .p25, .p50, .p75, .p100], id: \.self) { lvl in
                        HabitCell(level: lvl, accent: accent, isToday: false, size: 11, radius: 2)
                    }
                    Text("More")
                        .font(.custom(FontFamily.sans, size: 11))
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Surface.mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                // Day types glossary
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Day types", action: "Glossary")
                    VStack(alignment: .leading, spacing: 12) {
                        EditorialLegend(num: "01", level: .p100, accent: accent,
                                        label: "All done", desc: "Every scheduled habit hit.")
                        EditorialLegend(num: "02", level: .p50, accent: accent,
                                        label: "Partial", desc: "Some habits done.")
                        EditorialLegend(num: "03", level: .rest, accent: accent,
                                        label: "Rest day", desc: "Nothing scheduled — guilt-free.")
                        EditorialLegend(num: "04", level: .future, accent: accent,
                                        label: "Future", desc: "Days yet to come.")
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .background(DesignTokens.Surface.bg)
        .sheet(item: Binding(
            get: { detailDate.map { DateRef(date: $0) } },
            set: { detailDate = $0?.date }
        )) { ref in
            DayDetailSheet(date: ref.date, habits: filteredHabits, accent: accent)
                .environmentObject(repo)
        }
    }

    private var ledgerCard: some View {
        GlassCard(cornerRadius: 14, padding: 0) {
            HStack(spacing: 0) {
                LedgerStat(
                    label: "30 Day",
                    value: "\(Int(stats.consistency(habits: filteredHabits, window: 30) * 100))%",
                    accent: accent
                )
                Rectangle()
                    .fill(DesignTokens.Surface.hairline())
                    .frame(width: 1, height: 44)
                LedgerStat(
                    label: "Streak",
                    value: "\(stats.currentStreak(habits: filteredHabits))D",
                    accent: DesignTokens.Semantic.warn,
                    showPip: true
                )
                Rectangle()
                    .fill(DesignTokens.Surface.hairline())
                    .frame(width: 1, height: 44)
                LedgerStat(
                    label: "Best",
                    value: "\(stats.bestStreak(habits: filteredHabits))D",
                    accent: DesignTokens.Surface.fg()
                )
            }
            .padding(.vertical, 14)
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
