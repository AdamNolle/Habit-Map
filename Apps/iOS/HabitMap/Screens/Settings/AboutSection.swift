import SwiftUI
import HabitMapCore

struct AboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("About")
                .font(.custom(FontFamily.sans, size: 11))
                .fontWeight(.semibold)
                .kerning(0.5)
                .textCase(.uppercase)
                .foregroundColor(DesignTokens.Surface.mutedText)
                .padding(.top, 8)
                .padding(.leading, 2)
            row(label: "Version", value: HabitMapCore.version)
            row(label: "Build", value: buildNumber)
            navRow(label: "Privacy policy") {
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
            Text(label)
                .font(.custom(FontFamily.sans, size: 14))
                .fontWeight(.medium)
                .foregroundColor(DesignTokens.Surface.mutedText)
            Spacer()
            Text(value)
                .font(.custom(FontFamily.mono, size: 14))
                .fontWeight(.semibold)
                .foregroundColor(DesignTokens.Surface.fg())
        }
        .padding(12)
        .background(DesignTokens.Surface.card)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(DesignTokens.Surface.hairline(), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func navRow(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.custom(FontFamily.sans, size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Accent.classicGreen)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(DesignTokens.Accent.classicGreen)
            }
            .padding(12)
            .background(DesignTokens.Surface.card)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(DesignTokens.Surface.hairline(), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
