import SwiftUI
import SwiftData
import HabitMapCore

struct MapView: View {
    @Query(filter: #Predicate<HabitPage> { !$0.isArchived },
           sort: \HabitPage.sortOrder) private var pages: [HabitPage]
    @EnvironmentObject private var repo: HabitRepository
    @EnvironmentObject private var haptics: Haptics

    @State private var selectedPageID: UUID?
    @State private var detailDate: Date?
    @State private var cachedStats = CachedStats()
    private let stats = StatsService()

    /// Snapshot of everything that's expensive to derive from the habit set: the three
    /// streak/consistency scans (each up to ~730 days) and the precomputed 252-cell
    /// (36-week) heatmap. Cached and only rebuilt when `signature` changes.
    private struct CachedStats {
        var signature: Int?
        var consistency30: Double = 0
        var currentStreak: Int = 0
        var bestStreak: Int = 0
        var heatmap: CalendarHeatmap?
    }

    var body: some View {
        // Resolve the filtered set once per body evaluation instead of 6× via the
        // computed property (consistency text, 3 ledger stats, the heatmap).
        let habits = filteredHabits
        // Previously the three streak/consistency scans AND the 252-cell heatmap were
        // rebuilt on EVERY body eval — including the frequent ones from filter taps and
        // sheet open/close. Resolve them from a signature-keyed cache; the heavy work
        // only happens when the underlying data actually changes (see `.task` below).
        let signature = Self.statsSignature(for: habits, pageID: selectedPageID)
        let snapshot = cachedStats.signature == signature
            ? cachedStats
            : makeStats(for: habits, signature: signature)
        return ScrollView {
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
                    Text("Every habit, every day. \(Int(snapshot.consistency30 * 100))% consistency.")
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
                ledgerCard(consistency30: snapshot.consistency30,
                           currentStreak: snapshot.currentStreak,
                           bestStreak: snapshot.bestStreak)

                // Calendar atlas
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Calendar", action: "36 weeks")
                    GlassCard(cornerRadius: 18, padding: 16) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            if let heatmap = snapshot.heatmap {
                                heatmap
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
                .environmentObject(haptics)
        }
        .task(id: signature) {
            // Warm the cache off the render path so the frequent incidental re-renders
            // (sheet open/close, animations) hit the fast path above. The `body`
            // fallback already computed the correct values this frame; this stores them.
            if cachedStats.signature != signature {
                cachedStats = makeStats(for: habits, signature: signature)
            }
        }
    }

    /// Recompute the expensive snapshot for `habits`. Returns a value (never assigns
    /// `@State`) so it's safe to call from `body` as a fallback when the cache is stale.
    private func makeStats(for habits: [Habit], signature: Int) -> CachedStats {
        CachedStats(
            signature: signature,
            consistency30: stats.consistency(habits: habits, window: 30),
            currentStreak: stats.currentStreak(habits: habits),
            bestStreak: stats.bestStreak(habits: habits),
            heatmap: CalendarHeatmap(habits: habits, accent: accent, weeks: 36, cellSize: 8) { date in
                detailDate = date
            }
        )
    }

    /// Digest that changes exactly when the displayed stats/heatmap would: the day
    /// boundary, the selected scope, and each habit's schedule + completion data
    /// (count/reps/slipped, folded order-independently to avoid false cache misses).
    private static func statsSignature(for habits: [Habit], pageID: UUID?) -> Int {
        var hasher = Hasher()
        hasher.combine(Calendar.current.startOfDay(for: Date()))
        hasher.combine(pageID)
        for habit in habits {
            hasher.combine(habit.id)
            hasher.combine(habit.createdAt)
            hasher.combine(habit.weekdayMask)
            hasher.combine(habit.restDayMask)
            hasher.combine(habit.typeRaw)
            hasher.combine(habit.targetReps)
            hasher.combine(habit.healthGoal)
            let completions = habit.completions ?? []
            var repsSum = 0
            var slipCount = 0
            var dayFold = 0
            for completion in completions {
                repsSum &+= completion.reps
                if completion.slipped { slipCount += 1 }
                dayFold ^= completion.date.hashValue
            }
            hasher.combine(completions.count)
            hasher.combine(repsSum)
            hasher.combine(slipCount)
            hasher.combine(dayFold)
        }
        return hasher.finalize()
    }

    private func ledgerCard(consistency30: Double, currentStreak: Int, bestStreak: Int) -> some View {
        GlassCard(cornerRadius: 14, padding: 0) {
            HStack(spacing: 0) {
                LedgerStat(
                    label: "30 Day",
                    value: "\(Int(consistency30 * 100))%",
                    accent: accent
                )
                Rectangle()
                    .fill(DesignTokens.Surface.hairline())
                    .frame(width: 1, height: 44)
                LedgerStat(
                    label: "Streak",
                    value: "\(currentStreak)D",
                    accent: DesignTokens.Semantic.warn,
                    showPip: true
                )
                Rectangle()
                    .fill(DesignTokens.Surface.hairline())
                    .frame(width: 1, height: 44)
                LedgerStat(
                    label: "Best",
                    value: "\(bestStreak)D",
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
