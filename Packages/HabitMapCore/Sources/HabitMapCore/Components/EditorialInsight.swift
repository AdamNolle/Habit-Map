import SwiftUI

/// Numbered editorial insight row with colored left-border accent.
/// Used in InsightsView's "Patterns" section.
public struct EditorialInsight: View {
    let insight: Insight
    let index: Int

    public init(insight: Insight, index: Int) {
        self.insight = insight
        self.index = index
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(String(format: "%02d", index + 1))
                .font(.custom(FontFamily.mono, size: 11))
                .fontWeight(.semibold)
                .tracking(11 * 0.08)
                .foregroundColor(kindAccent)
                .frame(minWidth: 22, alignment: .leading)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 6) {
                Text(insight.title)
                    .font(.custom(FontFamily.serifItalic, size: 17))
                    .kerning(-0.2)
                    .foregroundColor(DesignTokens.Surface.fg())
                    .lineSpacing(2)

                Text(insight.body)
                    .font(.custom(FontFamily.sans, size: 13))
                    .foregroundColor(DesignTokens.Surface.fgDim())
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 14)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(kindAccent.opacity(0.30))
                    .frame(width: 1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.title). \(insight.body)")
    }

    private var kindAccent: Color {
        switch insight.kind {
        case .win:     return DesignTokens.Accent.classicGreen
        case .risk:    return DesignTokens.Semantic.danger
        case .suggest: return DesignTokens.Semantic.info
        }
    }
}
