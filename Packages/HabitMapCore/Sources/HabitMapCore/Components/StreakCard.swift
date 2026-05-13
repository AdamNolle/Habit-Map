import SwiftUI

public struct StreakCard: View {
    let consistency: Double
    let currentStreak: Int
    let bestStreak: Int
    let accent: Color

    public init(consistency: Double, currentStreak: Int, bestStreak: Int, accent: Color) {
        self.consistency = consistency
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.accent = accent
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            cell(label: "30D", value: "\(Int(consistency * 100))%")
            divider
            cell(label: "STREAK", value: "\(currentStreak)")
            divider
            cell(label: "BEST", value: "\(bestStreak)")
        }
        .padding(10)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(accent, lineWidth: 2))
    }

    private func cell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            MonoText(value, size: .title, weight: .heavy, color: accent)
            MonoText.label(label)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignTokens.Surface.cardBorder)
            .frame(width: 1)
    }
}
