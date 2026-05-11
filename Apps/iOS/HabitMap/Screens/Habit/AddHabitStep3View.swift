import SwiftUI
import HabitMapCore

struct AddHabitStep3View: View {
    @Binding var draft: WizardDraft
    let pageAccent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            PixelText("STEP 3 - WHEN", pixelSize: 2, color: DesignTokens.Surface.mutedText)

            VStack(alignment: .leading, spacing: 10) {
                PixelText("DAYS", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                WeekdayPicker(mask: $draft.weekdayMask, accent: Color(hex: draft.accentHex))
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    PixelText("REMINDER", pixelSize: 2, color: DesignTokens.Surface.mutedText)
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
