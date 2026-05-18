import SwiftUI
import SwiftData
import HabitMapCore

struct InsightsView: View {
    @Query(filter: #Predicate<HabitPage> { !$0.isArchived }) private var pages: [HabitPage]
    @State private var showRiskExpanded = false

    private let insightsEngine = InsightsEngine()
    private let riskEngine = RiskForecastEngine()

    var body: some View {
        let habits = pages.flatMap { ($0.habits ?? []).filter { !$0.isArchived && !$0.isPaused } }
        let insights = insightsEngine.generate(habits: habits)
        let forecast = riskEngine.forecast(habits: habits)
        let accent = DesignTokens.Accent.classicGreen

        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                PixelText("INSIGHTS", pixelSize: 3, color: accent)
                    .accessibilityLabel("INSIGHTS")
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.top, DesignTokens.Spacing.md)

                if insights.isEmpty {
                    MonoText("Not enough data yet — keep logging and we'll surface patterns here.",
                             size: .body, weight: .regular,
                             color: DesignTokens.Surface.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                } else {
                    LazyVStack(spacing: DesignTokens.Spacing.sm) {
                        ForEach(insights) { insight in
                            InsightCard(insight: insight)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                }

                Button {
                    showRiskExpanded = true
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            MonoText("RISK WINDOWS", size: .footnote, weight: .heavy, color: accent)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(accent)
                        }
                        RiskHeatmap(forecast: forecast, accent: accent, cellSize: 26, showLabels: true)
                    }
                    .padding(10)
                    .background(DesignTokens.Surface.card)
                    .overlay(Rectangle().stroke(accent, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("RISK WINDOWS, tap to expand")
                .padding(.horizontal, DesignTokens.Spacing.md)

                Spacer(minLength: 24)
            }
            .padding(.bottom, DesignTokens.Spacing.lg)
        }
        .background(DesignTokens.Surface.bg)
        .sheet(isPresented: $showRiskExpanded) {
            RiskExpandedView(forecast: forecast, accent: accent)
        }
        .preferredColorScheme(.dark)
    }
}
