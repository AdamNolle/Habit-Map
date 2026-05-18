import SwiftUI
import HabitMapCore

struct RiskExpandedView: View {
    @Environment(\.dismiss) private var dismiss
    let forecast: RiskForecast
    let accent: Color

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    PixelText("RISK FORECAST", pixelSize: 3, color: accent)
                        .accessibilityLabel("RISK FORECAST")
                        .accessibilityAddTraits(.isHeader)
                    MonoText("Where your habits tend to slip, by weekday and time of day. Darker = higher chance of missing.",
                             size: .body, weight: .regular,
                             color: DesignTokens.Surface.mutedText)
                        .fixedSize(horizontal: false, vertical: true)

                    RiskHeatmap(forecast: forecast, accent: accent, cellSize: 32)

                    if !forecast.topRisks.isEmpty {
                        MonoText.label("TOP WINDOWS")
                        ForEach(forecast.topRisks.indices, id: \.self) { idx in
                            let window = forecast.topRisks[idx]
                            HStack(spacing: 10) {
                                Rectangle()
                                    .fill(windowColor(window.level))
                                    .frame(width: 24, height: 24)
                                    .overlay(Rectangle().stroke(.black, lineWidth: 1))
                                VStack(alignment: .leading, spacing: 2) {
                                    MonoText("\(InsightsEngine.weekdayName(window.weekday).uppercased()) \(InsightsEngine.bucketLabel(window.bucket).uppercased())",
                                             size: .footnote, weight: .heavy, color: accent)
                                    MonoText("\(window.attempts) attempts", size: .caption, weight: .regular,
                                             color: DesignTokens.Surface.mutedText)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(DesignTokens.Surface.card)
                            .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
                        }
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
            .background(DesignTokens.Surface.bg)
            .navigationTitle("RISK")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func windowColor(_ level: RiskLevel) -> Color {
        switch level {
        case .danger: return DesignTokens.Surface.miss
        case .warn:   return Color(hex: "#FFB23D")
        default:      return DesignTokens.Surface.inactive
        }
    }
}
