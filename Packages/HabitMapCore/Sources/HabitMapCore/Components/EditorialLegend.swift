import SwiftUI

/// Numbered legend row with cell swatch, serif label, and muted description.
/// Used in MapView's "Day types" glossary section.
public struct EditorialLegend: View {
    let num: String
    let level: CellLevel
    let accent: Color
    let label: String
    let desc: String

    public init(num: String, level: CellLevel, accent: Color, label: String, desc: String) {
        self.num = num
        self.level = level
        self.accent = accent
        self.label = label
        self.desc = desc
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(num)
                .font(.custom(FontFamily.mono, size: 11))
                .fontWeight(.semibold)
                .tracking(11 * 0.08)
                .foregroundColor(DesignTokens.Surface.dimText)
                .frame(minWidth: 22, alignment: .leading)

            HStack(alignment: .center, spacing: 12) {
                HabitCell(level: level, accent: accent, isToday: false, size: 18, radius: 3)
                    .fixedSize()

                Text(label)
                    .font(.custom(FontFamily.serifItalic, size: 16))
                    .kerning(-0.2)
                    .foregroundColor(DesignTokens.Surface.fg())
                    .fixedSize()

                Text("· \(desc)")
                    .font(.custom(FontFamily.sans, size: 12.5))
                    .foregroundColor(DesignTokens.Surface.mutedText)
                    .lineLimit(1)
            }
            .padding(.leading, 14)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(DesignTokens.Surface.hairline())
                    .frame(width: 1)
            }
        }
    }
}
