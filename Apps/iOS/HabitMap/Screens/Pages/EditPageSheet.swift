import SwiftUI
import HabitMapCore

struct EditPageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repo: HabitRepository
    @Bindable var page: HabitPage

    @State private var name: String
    @State private var emoji: String
    @State private var accentHex: String

    init(page: HabitPage) {
        self.page = page
        self._name = State(initialValue: page.name)
        self._emoji = State(initialValue: page.emoji)
        self._accentHex = State(initialValue: page.accentHex)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    section(title: "NAME") {
                        TextField("name", text: $name)
                            .textInputAutocapitalization(.characters)
                            .font(.system(.body, design: .monospaced).weight(.heavy))
                            .padding(12)
                            .background(DesignTokens.Surface.tile)
                            .overlay(Rectangle().stroke(DesignTokens.Surface.tileBorder, lineWidth: 2))
                    }
                    section(title: "EMOJI") {
                        EmojiPicker(selected: $emoji, accent: Color(hex: accentHex))
                    }
                    section(title: "ACCENT") {
                        AccentSwatchPicker(selectedHex: $accentHex)
                    }
                    PixelButton("SAVE",
                                accent: Color(hex: accentHex),
                                isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty) {
                        do {
                            try repo.updatePage(page, name: name, emoji: emoji, accentHex: accentHex)
                            dismiss()
                        } catch { print("Update page failed: \(error)") }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .background(DesignTokens.Surface.bg)
            .navigationTitle("EDIT PAGE")
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
        VStack(alignment: .leading, spacing: 10) {
            PixelText(title, pixelSize: 2, color: DesignTokens.Surface.mutedText)
            content()
        }
    }
}
