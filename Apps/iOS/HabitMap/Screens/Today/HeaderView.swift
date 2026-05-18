import SwiftUI
import HabitMapCore

struct TodayHeader: View {
    let page: HabitPage
    let doneCount: Int
    let total: Int
    var onOpenPages: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button { onOpenPages?() } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignTokens.Surface.mutedText)
                        .frame(width: 30, height: 30)
                        .background(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Manage pages")
            }
            .padding(.bottom, 12)

            Eyebrow(HabitDateLabel.today(),
                    color: page.accentColor,
                    showPip: true)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 0) {
                    Display(greeting, size: 52, italic: true)
                    Display(page.name.titleCased + ".", size: 28,
                            color: page.accentColor, italic: true)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    PixelRing(filledSegments: PixelRing.segments(for: progress),
                              accent: page.accentColor)
                        .frame(width: 104, height: 104)

                    VStack(spacing: 2) {
                        MonoNum(String(doneCount), size: 26,
                                color: page.accentColor, glow: true)
                        Text("of \(total)")
                            .font(.custom(FontFamily.sans, size: 10))
                            .fontWeight(.semibold)
                            .tracking(10 * 0.08)
                            .foregroundColor(DesignTokens.Surface.mutedText)
                            .textCase(.uppercase)
                    }
                }
                .fixedSize()
            }
            .padding(.top, 14)

            DashRule(accent: page.accentColor)
                .padding(.top, 18)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var progress: Double {
        total > 0 ? Double(doneCount) / Double(total) : 0
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 5  { return "Good evening" }
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }
}
