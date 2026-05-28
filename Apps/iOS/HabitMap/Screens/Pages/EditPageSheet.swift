import SwiftUI
import HabitMapCore

struct EditPageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repo: HabitRepository
    @EnvironmentObject private var haptics: Haptics
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
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    section(title: "NAME") {
                        TextField("Page name", text: $name)
                            .textInputAutocapitalization(.words)
                            .font(.custom(FontFamily.sans, size: 16))
                            .fontWeight(.medium)
                            .padding(12)
                            .background(DesignTokens.Surface.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(DesignTokens.Surface.hairline(), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    section(title: "EMOJI") {
                        EmojiPicker(selected: $emoji, accent: Color(hex: accentHex))
                    }
                    section(title: "ACCENT") {
                        AccentSwatchPicker(selectedHex: $accentHex)
                    }
                    AppButton("SAVE",
                                accent: Color(hex: accentHex),
                                isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty) {
                        do {
                            try repo.updatePage(page, name: name, emoji: emoji, accentHex: accentHex)
                            haptics.success()
                            dismiss()
                        } catch { }
                    }
                }
                .padding(DesignTokens.Spacing.md)
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
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.titleCased)
                .font(.custom(FontFamily.sans, size: 11))
                .fontWeight(.semibold)
                .kerning(0.5)
                .textCase(.uppercase)
                .foregroundColor(DesignTokens.Surface.mutedText)
            content()
        }
    }
}
