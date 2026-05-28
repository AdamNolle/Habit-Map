import SwiftUI
import HabitMapCore

struct AddHabitStep3View: View {
    @Binding var draft: WizardDraft
    let pageAccent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Step 3 — When")
                .font(.custom(FontFamily.sans, size: 11))
                .fontWeight(.semibold)
                .kerning(0.5)
                .textCase(.uppercase)
                .foregroundColor(DesignTokens.Surface.mutedText)

            VStack(alignment: .leading, spacing: 8) {
                Text("Days")
                    .font(.custom(FontFamily.sans, size: 11))
                    .fontWeight(.semibold)
                    .kerning(0.5)
                    .textCase(.uppercase)
                    .foregroundColor(DesignTokens.Surface.mutedText)
                WeekdayPicker(mask: $draft.weekdayMask, accent: Color(hex: draft.accentHex))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Reminder")
                        .font(.custom(FontFamily.sans, size: 11))
                        .fontWeight(.semibold)
                        .kerning(0.5)
                        .textCase(.uppercase)
                        .foregroundColor(DesignTokens.Surface.mutedText)
                    Spacer()
                    Toggle("", isOn: $draft.reminderEnabled)
                        .tint(Color(hex: draft.accentHex))
                        .labelsHidden()
                }
                if draft.reminderEnabled {
                    DatePicker("",
                               selection: $draft.reminderTime,
                               displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .background(DesignTokens.Surface.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }
}
