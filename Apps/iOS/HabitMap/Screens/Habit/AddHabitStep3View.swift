import SwiftUI
import HabitMapCore

struct AddHabitStep3View: View {
    @Binding var draft: WizardDraft
    let pageAccent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            MonoText("STEP 3 — WHEN", size: .caption, weight: .heavy,
                     color: DesignTokens.Surface.mutedText)

            VStack(alignment: .leading, spacing: 8) {
                MonoText.label("DAYS")
                WeekdayPicker(mask: $draft.weekdayMask, accent: Color(hex: draft.accentHex))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    MonoText.label("REMINDER")
                    Spacer()
                    PixelToggle(isOn: $draft.reminderEnabled, accent: Color(hex: draft.accentHex))
                }
                if draft.reminderEnabled {
                    DatePicker("",
                               selection: $draft.reminderTime,
                               displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .background(DesignTokens.Surface.tile)
                        .overlay(Rectangle().stroke(DesignTokens.Surface.tileBorder, lineWidth: 2))
                }
            }
        }
    }
}
