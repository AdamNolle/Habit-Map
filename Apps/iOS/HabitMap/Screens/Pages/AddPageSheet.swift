import SwiftUI
import HabitMapCore

struct AddPageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repo: HabitRepository

    @State private var name: String = ""
    @State private var emoji: String = "🩺"
    @State private var accentHex: String = "#2BFF5F"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    section(title: "NAME") {
                        TextField("e.g. HEALTH", text: $name)
                            .textInputAutocapitalization(.characters)
                            .font(.system(.body, design: .monospaced).weight(.heavy))
                            .padding(10)
                            .background(DesignTokens.Surface.tile)
                            .overlay(Rectangle().stroke(DesignTokens.Surface.tileBorder, lineWidth: 2))
                    }
                    section(title: "EMOJI") {
                        EmojiPicker(selected: $emoji, accent: Color(hex: accentHex))
                    }
                    section(title: "ACCENT") {
                        AccentSwatchPicker(selectedHex: $accentHex)
                    }
                    PixelButton("CREATE PAGE",
                                style: .primary,
                                accent: Color(hex: accentHex),
                                isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty) {
                        do {
                            try repo.createPage(name: name, emoji: emoji, accentHex: accentHex)
                            dismiss()
                        } catch { print("Create page failed: \(error)") }
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
            .background(DesignTokens.Surface.bg)
            .navigationTitle("NEW PAGE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MonoText.label(title)
            content()
        }
    }
}
