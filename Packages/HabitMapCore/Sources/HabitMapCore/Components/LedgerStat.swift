import SwiftUI

/// Single column in a 3-up stat ledger. Shows a large mono value + small eyebrow label.
public struct LedgerStat: View {
    let label: String
    let value: String
    let accent: Color
    let showPip: Bool

    public init(label: String, value: String, accent: Color, showPip: Bool = false) {
        self.label = label
        self.value = value
        self.accent = accent
        self.showPip = showPip
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                if showPip {
                    Pip(color: accent, size: 5)
                        .padding(.bottom, 3)
                }
                MonoNum(value, size: 22, color: accent)
            }
            Text(label.uppercased())
                .font(.custom(FontFamily.sans, size: 9.5))
                .fontWeight(.semibold)
                .tracking(9.5 * 0.18)
                .foregroundColor(DesignTokens.Surface.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}
