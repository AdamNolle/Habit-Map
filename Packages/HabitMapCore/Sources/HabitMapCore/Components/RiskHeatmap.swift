import SwiftUI

public struct RiskHeatmap: View {
    let forecast: RiskForecast
    let accent: Color
    let cellSize: CGFloat
    let showLabels: Bool

    public init(forecast: RiskForecast, accent: Color, cellSize: CGFloat = 28, showLabels: Bool = true) {
        self.forecast = forecast
        self.accent = accent
        self.cellSize = cellSize
        self.showLabels = showLabels
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showLabels {
                HStack(spacing: 4) {
                    Color.clear.frame(width: 24, height: cellSize * 0.5)
                    ForEach(0..<8, id: \.self) { b in
                        PixelText(Self.bucketAbbrev(b), pixelSize: 1, color: DesignTokens.Surface.mutedText)
                            .frame(width: cellSize)
                    }
                }
            }
            ForEach(0..<7, id: \.self) { wd in
                HStack(spacing: 4) {
                    if showLabels {
                        PixelText(Self.weekdayLetter(wd), pixelSize: 2, color: DesignTokens.Surface.mutedText)
                            .frame(width: 24, alignment: .leading)
                    }
                    ForEach(0..<8, id: \.self) { bucket in
                        Rectangle()
                            .fill(color(for: forecast.matrix[wd][bucket]))
                            .frame(width: cellSize, height: cellSize)
                            .overlay(Rectangle().stroke(.black, lineWidth: 1))
                    }
                }
            }
        }
        .accessibilityLabel("Risk forecast heatmap")
    }

    private func color(for level: RiskLevel) -> Color {
        switch level {
        case .noData:     return DesignTokens.Surface.inactive
        case .completed4: return accent
        case .completed3: return accent.darker(by: 0.15)
        case .completed2: return accent.darker(by: 0.3)
        case .completed1: return DesignTokens.Surface.mutedText
        case .warn:       return Color(hex: "#FFB23D")
        case .danger:     return DesignTokens.Surface.miss
        }
    }

    static func bucketAbbrev(_ b: Int) -> String {
        ["6A", "9A", "12P", "3P", "6P", "9P", "12A", "3A"][b]
    }

    static func weekdayLetter(_ wd: Int) -> String {
        ["M", "T", "W", "T", "F", "S", "S"][wd]
    }
}
