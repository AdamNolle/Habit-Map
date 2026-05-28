import SwiftUI
import SwiftData
import HabitMapCore

struct InsightsView: View {
    @Query(filter: #Predicate<HabitPage> { !$0.isArchived },
           sort: \HabitPage.sortOrder) private var pages: [HabitPage]
    @EnvironmentObject private var haptics: Haptics
    @State private var showRiskExpanded = false
    @State private var showCoachChat = false

    private let insightsEngine = InsightsEngine()
    private let riskEngine = RiskForecastEngine()
    private let extractor = SlipFeatureExtractor()
    private let stats = StatsService()
    private let accent = DesignTokens.Accent.classicGreen

    var body: some View {
        let habits = pages.flatMap { ($0.habits ?? []).filter { !$0.isArchived && !$0.isPaused } }
        let insights = insightsEngine.generate(habits: habits)
        let forecast = riskEngine.forecast(habits: habits)
        let features = extractor.extract(habits: habits)
        let consistency = stats.consistency(habits: habits, window: 30)
        let streak = stats.currentStreak(habits: habits)
        let best = stats.bestStreak(habits: habits)
        let series = stats.consistencySeries(habits: habits, window: 30)

        let prevHalf = series.prefix(15).reduce(0, +) / max(1, Double(min(15, series.count)))
        let recentHalf = series.suffix(15).reduce(0, +) / max(1, Double(min(15, series.count)))
        let trend = recentHalf - prevHalf

        ScrollView {
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
                        PulseChart(data: series, accent: accent)
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
                                pageCard(page: page)
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
    }

    private func pageCard(page: HabitPage) -> some View {
        let pageHabits = (page.habits ?? []).filter { !$0.isArchived && !$0.isPaused }
        let pct = Int(stats.consistency(habits: pageHabits, window: 30) * 100)
        let pStreak = stats.currentStreak(habits: pageHabits)
        let pSeries = stats.consistencySeries(habits: pageHabits, window: 30)

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
