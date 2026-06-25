import SwiftUI
import SwiftData
import HabitMapCore

struct InsightsView: View {
    @Query(filter: #Predicate<HabitPage> { !$0.isArchived },
           sort: \HabitPage.sortOrder) private var pages: [HabitPage]
    @EnvironmentObject private var haptics: Haptics
    @State private var showRiskExpanded = false
    @State private var showCoachChat = false
    @State private var cachedReport: Report?

    private let insightsEngine = InsightsEngine()
    private let riskEngine = RiskForecastEngine()
    private let extractor = SlipFeatureExtractor()
    private let stats = StatsService()
    private let accent = DesignTokens.Accent.classicGreen

    var body: some View {
        // The four engines each scan a 30-day window; recompute only when the
        // underlying habit data changes, not on every sheet toggle / re-render.
        let activeHabits = pages.flatMap { ($0.habits ?? []).filter { !$0.isArchived && !$0.isPaused } }
        let sig = Self.signature(for: activeHabits)
        // Render straight from the cache; never call makeReport in body (that would double-compute
        // and, if assigned to @State, warn about mutating state during view update). The async
        // .task(id: sig) below computes the report exactly once per data change.
        let report = (cachedReport?.signature == sig ? cachedReport : nil)
            ?? Self.placeholderReport(signature: sig)

        let insights = report.insights
        let forecast = report.forecast
        let features = report.features
        let consistency = report.consistency
        let streak = report.streak
        let best = report.best
        let series = report.series
        let trend = report.trend

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Masthead
                Text("Habit Map · No.18 · Insights")
                    .font(.custom(FontFamily.mono, size: 10))
                    .fontWeight(.semibold)
                    .tracking(10 * 0.22)
                    .textCase(.uppercase)
                    .foregroundColor(DesignTokens.Surface.mutedText)

                // Hero
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow("\(HabitDateLabel.today()) · 30 day window",
                            color: accent, showPip: true)
                    HStack(alignment: .lastTextBaseline, spacing: 12) {
                        Display("The pulse", size: 50, italic: true)
                        Display("—report", size: 28, color: accent, italic: true)
                    }
                    .padding(.top, 14)
                    Text("How your habits are trending across the last month.")
                        .font(.custom(FontFamily.sans, size: 14))
                        .italic()
                        .foregroundColor(DesignTokens.Surface.mutedText)
                        .padding(.top, 10)
                }

                DashRule(accent: accent)

                // Pulse chart card
                GlassCard(cornerRadius: 18, padding: 18) {
                    VStack(spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Eyebrow("Daily consistency",
                                        color: DesignTokens.Surface.mutedText)
                                HStack(alignment: .lastTextBaseline, spacing: 4) {
                                    MonoNum(String(Int(consistency * 100)), size: 44,
                                            color: accent, glow: true)
                                    MonoNum("%", size: 20, color: accent)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                Eyebrow("Trend", color: DesignTokens.Surface.mutedText)
                                HStack(spacing: 4) {
                                    Text("\(trend >= 0 ? "+" : "")\(Int(trend * 100))%")
                                        .font(.custom(FontFamily.mono, size: 16))
                                        .fontWeight(.bold)
                                        .monospacedDigit()
                                        .foregroundColor(trend >= 0 ? accent : DesignTokens.Semantic.danger)
                                    Text(trend >= 0 ? "↑" : "↓")
                                        .font(.system(size: 14))
                                        .foregroundColor(trend >= 0 ? accent : DesignTokens.Semantic.danger)
                                }
                                Text("vs prior 15d")
                                    .font(.custom(FontFamily.sans, size: 11))
                                    .foregroundColor(DesignTokens.Surface.dimText)
                            }
                        }
                        PulseChart(data: series.compactMap { $0 }, accent: accent)
                            .frame(height: 100)
                    }
                }

                // AI coach card
                Button { haptics.sheetPresent(); showCoachChat = true } label: {
                    CoachSection(features: features) { haptics.sheetPresent(); showCoachChat = true }
                }
                .buttonStyle(.plain)

                // 3-col ledger
                GlassCard(cornerRadius: 14, padding: 0) {
                    HStack(spacing: 0) {
                        LedgerStat(label: "This month",
                                   value: "\(Int(consistency * 100))%",
                                   accent: accent)
                        Rectangle()
                            .fill(DesignTokens.Surface.hairline())
                            .frame(width: 1, height: 44)
                        LedgerStat(label: "Streak",
                                   value: "\(streak)D",
                                   accent: DesignTokens.Semantic.warn,
                                   showPip: true)
                        Rectangle()
                            .fill(DesignTokens.Surface.hairline())
                            .frame(width: 1, height: 44)
                        LedgerStat(label: "Best",
                                   value: "\(best)D",
                                   accent: DesignTokens.Surface.fg())
                    }
                    .padding(.vertical, 14)
                }

                // Per-page report
                if !pages.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("By page", action: "\(pages.count) pages")
                        VStack(spacing: 8) {
                            ForEach(pages) { page in
                                pageCard(page: page, stat: report.pageStats[page.persistentModelID])
                            }
                        }
                    }
                }

                // Patterns / insights
                if !insights.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader("Patterns", action: "This week")
                        VStack(spacing: 14) {
                            ForEach(Array(insights.enumerated()), id: \.element.id) { i, insight in
                                EditorialInsight(insight: insight, index: i)
                            }
                        }
                    }
                }

                // Risk windows
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Risk windows", action: "7D × 8H")
                    Button {
                        haptics.sheetPresent()
                        showRiskExpanded = true
                    } label: {
                        GlassCard(cornerRadius: 14, padding: 16) {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("The hours and days you tend to slip.")
                                    .font(.custom(FontFamily.sans, size: 12.5))
                                    .italic()
                                    .foregroundColor(DesignTokens.Surface.mutedText)
                                RiskHeatmap(forecast: forecast, accent: accent,
                                            cellSize: 26, showLabels: true)
                                riskLegend
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Risk windows, tap to expand")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .background(DesignTokens.Surface.bg)
        .sheet(isPresented: $showRiskExpanded) {
            RiskExpandedView(forecast: forecast, accent: accent)
                .environmentObject(haptics)
        }
        .sheet(isPresented: $showCoachChat) {
            CoachChatView(features: features)
                .environmentObject(haptics)
        }
        .task(id: sig) {
            cachedReport = makeReport(habits: activeHabits, signature: sig)
        }
    }

    // MARK: - Cached report

    /// Snapshot of all engine outputs for one habit-data state.
    private struct Report {
        let signature: Int
        let insights: [Insight]
        let forecast: RiskForecast
        let features: SlipFeatures
        let consistency: Double
        let streak: Int
        let best: Int
        let series: [Double?]
        let trend: Double
        let pageStats: [PersistentIdentifier: PageStat]
    }

    /// Per-page stats, computed once inside `makeReport` so `pageCard` never recomputes per render.
    private struct PageStat {
        let pct: Int
        let streak: Int
        let series: [Double?]
    }

    /// Lightweight stand-in shown for a frame while `.task` computes the real report for the
    /// current signature — keeps `makeReport` out of `body` (no double-compute, no state mutation
    /// during view update).
    private static func placeholderReport(signature sig: Int) -> Report {
        Report(signature: sig, insights: [], forecast: .empty, features: .empty,
               consistency: 0, streak: 0, best: 0, series: [], trend: 0, pageStats: [:])
    }

    private func makeReport(habits: [Habit], signature sig: Int) -> Report {
        let series = stats.consistencySeries(habits: habits, window: 30)
        // Trend compares the two halves of the window but SKIPS nil (pre-active / unscheduled) days
        // instead of counting them as 0.0 misses, which would understate a young habit.
        let prev = series.prefix(15).compactMap { $0 }
        let recent = series.suffix(15).compactMap { $0 }
        let prevHalf = prev.isEmpty ? 0 : prev.reduce(0, +) / Double(prev.count)
        let recentHalf = recent.isEmpty ? 0 : recent.reduce(0, +) / Double(recent.count)

        // Fold per-page stats into the cached report so pageCard reads them instead of recomputing.
        var pageStats: [PersistentIdentifier: PageStat] = [:]
        for page in pages {
            let pageHabits = (page.habits ?? []).filter { !$0.isArchived && !$0.isPaused }
            pageStats[page.persistentModelID] = PageStat(
                pct: Int(stats.consistency(habits: pageHabits, window: 30) * 100),
                streak: stats.currentStreak(habits: pageHabits),
                series: stats.consistencySeries(habits: pageHabits, window: 30)
            )
        }

        return Report(
            signature: sig,
            insights: insightsEngine.generate(habits: habits),
            forecast: riskEngine.forecast(habits: habits),
            features: extractor.extract(habits: habits),
            consistency: stats.consistency(habits: habits, window: 30),
            streak: stats.currentStreak(habits: habits),
            best: stats.bestStreak(habits: habits),
            series: series,
            trend: recentHalf - prevHalf,
            pageStats: pageStats
        )
    }

    /// Cheap digest that changes whenever completion data (add/remove/edit) or the
    /// day changes — used to invalidate the cached report.
    private static func signature(for habits: [Habit]) -> Int {
        var hasher = Hasher()
        hasher.combine(Calendar.current.startOfDay(for: Date()))
        for habit in habits {
            hasher.combine(habit.id)
            let comps = habit.completions ?? []
            hasher.combine(comps.count)
            for completion in comps {
                hasher.combine(completion.reps)
                hasher.combine(completion.slipped)
            }
        }
        return hasher.finalize()
    }

    private func pageCard(page: HabitPage, stat: PageStat?) -> some View {
        let pageHabits = (page.habits ?? []).filter { !$0.isArchived && !$0.isPaused }
        let pct = stat?.pct ?? 0
        let pStreak = stat?.streak ?? 0
        let pSeries = stat?.series ?? []

        return GlassCard(cornerRadius: 0, padding: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LinearGradient(
                            colors: [page.accentColor.opacity(0.25), page.accentColor.opacity(0.06)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(page.accentColor.opacity(0.3), lineWidth: 1)
                        )
                    Text(page.emoji)
                        .font(.system(size: 15))
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(page.name.titleCased)
                        .font(.custom(FontFamily.sans, size: 14.5))
                        .fontWeight(.semibold)
                        .kerning(-0.2)
                        .foregroundColor(DesignTokens.Surface.fg())
                    Text("\(pageHabits.count) habits · \(pStreak)d streak")
                        .font(.custom(FontFamily.sans, size: 11))
                        .foregroundColor(DesignTokens.Surface.mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Sparkline(data: pSeries, accent: page.accentColor)
                    .frame(width: 60, height: 24)

                MonoNum(String(pct) + "%", size: 15, color: page.accentColor)
                    .frame(minWidth: 38, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(page.accentColor)
                .frame(width: 2)
                .clipShape(RoundedRectangle(cornerRadius: 0))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        }
    }

    private var riskLegend: some View {
        HStack(spacing: 12) {
            ForEach([
                (DesignTokens.Accent.classicGreen, "Hit"),
                (DesignTokens.Semantic.warn, "Warn"),
                (DesignTokens.Semantic.danger, "Danger"),
                (DesignTokens.Surface.tint2(), "No data")
            ], id: \.1) { color, label in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: 12, height: 12)
                    Text(label)
                        .font(.custom(FontFamily.sans, size: 11))
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Surface.mutedText)
                }
            }
        }
        .padding(.top, 2)
    }
}
