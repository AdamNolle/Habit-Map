import SwiftUI
import HabitMapCore

struct AddHabitStep1View: View {
    @Binding var draft: WizardDraft
    let pageAccent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            MonoText("STEP 1 — WHAT", size: .caption, weight: .heavy,
                     color: DesignTokens.Surface.mutedText)

            VStack(alignment: .leading, spacing: 8) {
                MonoText.label("NAME")
                TextField("e.g. DRINK WATER", text: $draft.name)
                    .textInputAutocapitalization(.characters)
                    .font(.system(.body, design: .monospaced).weight(.heavy))
                    .padding(10)
                    .background(DesignTokens.Surface.tile)
                    .overlay(Rectangle().stroke(DesignTokens.Surface.tileBorder, lineWidth: 2))
            }

            VStack(alignment: .leading, spacing: 8) {
                MonoText.label("EMOJI")
                EmojiPicker(selected: $draft.emoji, accent: Color(hex: draft.accentHex))
            }

            VStack(alignment: .leading, spacing: 8) {
                MonoText.label("ACCENT")
                AccentSwatchPicker(selectedHex: $draft.accentHex)
            }
        }
    }
}
