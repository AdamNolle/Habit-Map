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
                    Text("Risk forecast")
                        .font(.custom(FontFamily.serif, size: 22))
                        .italic()
                        .foregroundColor(DesignTokens.Surface.fg())

                    Text("Where your habits tend to slip, by weekday and time of day. Darker = higher chance of missing.")
                        .font(.custom(FontFamily.sans, size: 14))
                        .foregroundColor(DesignTokens.Surface.mutedText)
                        .fixedSize(horizontal: false, vertical: true)

                    RiskHeatmap(forecast: forecast, accent: accent, cellSize: 32)

                    if !forecast.topRisks.isEmpty {
                        Text("Top windows")
                            .font(.custom(FontFamily.sans, size: 11))
                            .fontWeight(.semibold)
                            .kerning(0.5)
                            .textCase(.uppercase)
                            .foregroundColor(DesignTokens.Surface.mutedText)
                            .padding(.top, 4)

                        ForEach(forecast.topRisks.indices, id: \.self) { idx in
                            let window = forecast.topRisks[idx]
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(windowColor(window.level))
                                    .frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(InsightsEngine.weekdayName(window.weekday).capitalized) \(InsightsEngine.bucketLabel(window.bucket))")
                                        .font(.custom(FontFamily.sans, size: 14))
                                        .fontWeight(.semibold)
                                        .foregroundColor(accent)
                                    Text("\(window.attempts) attempts")
                                        .font(.custom(FontFamily.sans, size: 12))
                                        .foregroundColor(DesignTokens.Surface.mutedText)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(DesignTokens.Surface.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(DesignTokens.Surface.hairline(), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
            .background(DesignTokens.Surface.bg)
            .navigationTitle("Risk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func windowColor(_ level: RiskLevel) -> Color {
        switch level {
        case .danger: return DesignTokens.Surface.miss
        case .warn:   return Color(hex: "#FFB23D")
        default:      return DesignTokens.Surface.inactive
        }
    }
}
