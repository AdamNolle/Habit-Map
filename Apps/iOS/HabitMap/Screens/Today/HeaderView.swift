import SwiftUI
import HabitMapCore

struct HeaderView: View {
    let page: HabitPage
    @State private var showPages = false

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                PixelText(page.name, pixelSize: 4, color: page.accentColor)
                    .accessibilityLabel(page.name)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitleText)
                    .font(.system(.caption2, design: .monospaced).weight(.heavy))
                    .tracking(1.0)
                    .foregroundColor(DesignTokens.Surface.mutedText)
            }
            Spacer()
            Button {
                showPages = true
            } label: {
                PixelIcon(.grid, color: DesignTokens.Surface.mutedText, size: 24)
            }
            .accessibilityLabel("Manage pages")
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.top, DesignTokens.Spacing.lg)
        .sheet(isPresented: $showPages) {
            PagesManagerView()
        }
    }

    private var subtitleText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE - MMM d"
        let dateStr = formatter.string(from: Date()).uppercased()
        let pending = (page.habits ?? []).filter { !$0.isArchived && !$0.isPaused }
        let done = pending.filter { $0.progressFraction(on: Date()) >= 1.0 }.count
        return "\(dateStr) - \(done) OF \(pending.count)"
    }
}
