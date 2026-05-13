import SwiftUI
import HabitMapCore

struct AboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PixelText("ABOUT", pixelSize: 3, color: DesignTokens.Accent.classicGreen)
                .padding(.top, 8)
            row(label: "VERSION", value: HabitMapCore.version)
            row(label: "BUILD", value: buildNumber)
            navRow(label: "PRIVACY POLICY") {
                if let url = URL(string: "https://habitmap.app/privacy") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            PixelText(label, pixelSize: 2, color: DesignTokens.Surface.mutedText)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced).weight(.heavy))
                .foregroundColor(.white)
        }
        .padding(12)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
    }

    private func navRow(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                PixelText(label, pixelSize: 2, color: DesignTokens.Accent.classicGreen)
                Spacer()
                PixelText(">", pixelSize: 2, color: DesignTokens.Accent.classicGreen)
            }
            .padding(12)
            .background(DesignTokens.Surface.card)
            .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
