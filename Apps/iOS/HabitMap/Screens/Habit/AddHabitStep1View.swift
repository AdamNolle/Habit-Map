import SwiftUI
import HabitMapCore

struct AddHabitStep1View: View {
    @Binding var draft: WizardDraft
    let pageAccent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Step 1 — What")
                .font(.custom(FontFamily.sans, size: 11))
                .fontWeight(.semibold)
                .kerning(0.5)
                .textCase(.uppercase)
                .foregroundColor(DesignTokens.Surface.mutedText)

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.custom(FontFamily.sans, size: 11))
                    .fontWeight(.semibold)
                    .kerning(0.5)
                    .textCase(.uppercase)
                    .foregroundColor(DesignTokens.Surface.mutedText)
                TextField("e.g. Drink Water", text: $draft.name)
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Emoji")
                    .font(.custom(FontFamily.sans, size: 11))
                    .fontWeight(.semibold)
                    .kerning(0.5)
                    .textCase(.uppercase)
                    .foregroundColor(DesignTokens.Surface.mutedText)
                EmojiPicker(selected: $draft.emoji, accent: Color(hex: draft.accentHex))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Accent")
                    .font(.custom(FontFamily.sans, size: 11))
                    .fontWeight(.semibold)
                    .kerning(0.5)
                    .textCase(.uppercase)
                    .foregroundColor(DesignTokens.Surface.mutedText)
                AccentSwatchPicker(selectedHex: $draft.accentHex)
            }
        }
    }
}
