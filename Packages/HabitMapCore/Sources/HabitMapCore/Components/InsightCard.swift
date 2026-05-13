import SwiftUI

public struct InsightCard: View {
    let insight: Insight

    public init(insight: Insight) {
        self.insight = insight
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            badge
            VStack(alignment: .leading, spacing: 4) {
                MonoText(insight.title, size: .footnote, weight: .heavy, color: accent)
                MonoText(insight.body, size: .body, weight: .regular,
                         color: DesignTokens.Surface.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(accent, lineWidth: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.title). \(insight.body)")
    }

    private var accent: Color {
        if let hex = insight.primaryAccentHex { return Color(hex: hex) }
        switch insight.kind {
        case .win:     return DesignTokens.Accent.classicGreen
        case .risk:    return DesignTokens.Surface.miss
        case .suggest: return DesignTokens.Accent.cobalt
        }
    }

    @ViewBuilder private var badge: some View {
        let bg: Color = {
            switch insight.kind {
            case .win:     return DesignTokens.Accent.classicGreen
            case .risk:    return DesignTokens.Surface.miss
            case .suggest: return DesignTokens.Accent.cobalt
            }
        }()
        Rectangle()
            .fill(bg)
            .frame(width: 24, height: 24)
            .overlay(Rectangle().stroke(bg.darker(by: 0.2), lineWidth: 2))
            .overlay(
                PixelText(badgeChar, pixelSize: 2, color: .black)
            )
    }

    private var badgeChar: String {
        switch insight.kind {
        case .win:     return "."
        case .risk:    return "!"
        case .suggest: return "?"
        }
    }
}
