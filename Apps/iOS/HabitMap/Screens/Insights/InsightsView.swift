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
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                PixelText("INSIGHTS", pixelSize: 4, color: accent)
                    .accessibilityLabel("INSIGHTS")
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.top, DesignTokens.Spacing.lg)

                if insights.isEmpty {
                    Text("Not enough data yet — keep logging and we'll surface patterns here.")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundColor(DesignTokens.Surface.mutedText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                } else {
                    LazyVStack(spacing: DesignTokens.Spacing.md) {
                        ForEach(insights) { insight in
                            InsightCard(insight: insight)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                }

                Button {
                    showRiskExpanded = true
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            PixelText("RISK WINDOWS", pixelSize: 3, color: accent)
                            Spacer()
                            PixelText(">", pixelSize: 2, color: accent)
                        }
                        RiskHeatmap(forecast: forecast, accent: accent, cellSize: 28, showLabels: true)
                    }
                    .padding(12)
                    .background(DesignTokens.Surface.card)
                    .overlay(Rectangle().stroke(accent, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("RISK WINDOWS, tap to expand")
                .padding(.horizontal, DesignTokens.Spacing.lg)

                Spacer(minLength: 24)
            }
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .background(DesignTokens.Surface.bg)
        .sheet(isPresented: $showRiskExpanded) {
            RiskExpandedView(forecast: forecast, accent: accent)
        }
        .preferredColorScheme(.dark)
    }
}
