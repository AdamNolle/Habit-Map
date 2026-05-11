import SwiftUI
import HabitMapCore

struct ComingSoonView: View {
    let title: String
    let plan: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            PixelText(title, pixelSize: 5, color: DesignTokens.Accent.classicGreen)
            PixelText("COMING IN \(plan)", pixelSize: 2, color: DesignTokens.Surface.mutedText)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Surface.bg)
        .preferredColorScheme(.dark)
    }
}
