import SwiftUI
import HabitMapCore

struct AboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MonoText("ABOUT", size: .caption, weight: .heavy,
                     color: DesignTokens.Accent.classicGreen)
                .padding(.top, 8)
                .padding(.leading, 2)
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
            MonoText.label(label)
            Spacer()
            MonoText(value, size: .body, weight: .heavy, color: .white)
        }
        .padding(10)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
    }

    private func navRow(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                MonoText(label, size: .footnote, weight: .heavy,
                         color: DesignTokens.Accent.classicGreen)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(DesignTokens.Accent.classicGreen)
            }
            .padding(10)
            .background(DesignTokens.Surface.card)
            .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
