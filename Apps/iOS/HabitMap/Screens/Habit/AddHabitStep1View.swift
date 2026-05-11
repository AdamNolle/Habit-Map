import SwiftUI
import HabitMapCore

struct AddHabitStep1View: View {
    @Binding var draft: WizardDraft
    let pageAccent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            PixelText("STEP 1 - WHAT", pixelSize: 2, color: DesignTokens.Surface.mutedText)

            VStack(alignment: .leading, spacing: 10) {
                PixelText("NAME", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                TextField("e.g. DRINK WATER", text: $draft.name)
                    .textInputAutocapitalization(.characters)
                    .font(.system(.body, design: .monospaced).weight(.heavy))
                    .padding(12)
                    .background(DesignTokens.Surface.tile)
                    .overlay(Rectangle().stroke(DesignTokens.Surface.tileBorder, lineWidth: 2))
            }

            VStack(alignment: .leading, spacing: 10) {
                PixelText("EMOJI", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                EmojiPicker(selected: $draft.emoji, accent: Color(hex: draft.accentHex))
            }

            VStack(alignment: .leading, spacing: 10) {
                PixelText("ACCENT", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                AccentSwatchPicker(selectedHex: $draft.accentHex)
            }
        }
    }
}
