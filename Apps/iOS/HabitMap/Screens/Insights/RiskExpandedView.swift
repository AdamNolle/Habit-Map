import SwiftUI
import HabitMapCore

struct RiskExpandedView: View {
    @Environment(\.dismiss) private var dismiss
    let forecast: RiskForecast
    let accent: Color

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    PixelText("RISK FORECAST", pixelSize: 4, color: accent)
                        .accessibilityLabel("RISK FORECAST")
                        .accessibilityAddTraits(.isHeader)
                    Text("Where your habits tend to slip, by weekday and time of day. Darker = higher chance of missing.")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundColor(DesignTokens.Surface.mutedText)
                        .fixedSize(horizontal: false, vertical: true)

                    RiskHeatmap(forecast: forecast, accent: accent, cellSize: 36)

                    if !forecast.topRisks.isEmpty {
                        PixelText("TOP WINDOWS", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                        ForEach(forecast.topRisks.indices, id: \.self) { idx in
                            let window = forecast.topRisks[idx]
                            HStack(spacing: 12) {
                                Rectangle()
                                    .fill(windowColor(window.level))
                                    .frame(width: 28, height: 28)
                                    .overlay(Rectangle().stroke(.black, lineWidth: 1))
                                VStack(alignment: .leading, spacing: 2) {
                                    PixelText("\(InsightsEngine.weekdayName(window.weekday).uppercased()) \(InsightsEngine.bucketLabel(window.bucket).uppercased())",
                                              pixelSize: 2,
                                              color: accent)
                                    Text("\(window.attempts) attempts")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(DesignTokens.Surface.mutedText)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(DesignTokens.Surface.card)
                            .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
                        }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
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
