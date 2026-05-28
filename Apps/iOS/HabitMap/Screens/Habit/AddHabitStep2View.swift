import SwiftUI
import HealthKit
import HabitMapCore

struct AddHabitStep2View: View {
    @Binding var draft: WizardDraft
    let pageAccent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Step 2 — How often")
                .font(.custom(FontFamily.sans, size: 11))
                .fontWeight(.semibold)
                .kerning(0.5)
                .textCase(.uppercase)
                .foregroundColor(DesignTokens.Surface.mutedText)

            VStack(alignment: .leading, spacing: 8) {
                Text("Type")
                    .font(.custom(FontFamily.sans, size: 11))
                    .fontWeight(.semibold)
                    .kerning(0.5)
                    .textCase(.uppercase)
                    .foregroundColor(DesignTokens.Surface.mutedText)
                typeRow(.manualOnce, label: "Once a day", subtitle: "Tap once when done")
                typeRow(.manualMultiple, label: "Multiple times", subtitle: "Tap N times to hit target")
                typeRow(.inverse, label: "Avoid", subtitle: "Default complete unless slipped")
                if HKHealthStore.isHealthDataAvailable() {
                    typeRow(.autoHealth, label: "Auto-fill from Health", subtitle: "Apple Health populates progress")
                }
            }

            if draft.type == .manualMultiple {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target reps")
                        .font(.custom(FontFamily.sans, size: 11))
                        .fontWeight(.semibold)
                        .kerning(0.5)
                        .textCase(.uppercase)
                        .foregroundColor(DesignTokens.Surface.mutedText)
                    HStack(spacing: DesignTokens.Spacing.md) {
                        AppButton("−", style: .glass, accent: Color(hex: draft.accentHex)) {
                            draft.targetReps = max(1, draft.targetReps - 1)
                        }.frame(width: 56)
                        Text("\(draft.targetReps)")
                            .font(.custom(FontFamily.mono, size: 28))
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: draft.accentHex))
                            .frame(maxWidth: .infinity)
                        AppButton("+", style: .glass, accent: Color(hex: draft.accentHex)) {
                            draft.targetReps = min(20, draft.targetReps + 1)
                        }.frame(width: 56)
                    }
                }
            } else if draft.type == .autoHealth {
                MetricPickerView(metric: $draft.healthMetric,
                                 goal: $draft.healthGoal,
                                 accent: Color(hex: draft.accentHex))
            }
        }
    }

    @ViewBuilder
    private func typeRow(_ type: HabitType, label: String, subtitle: String) -> some View {
        let selected = draft.type == type
        let accent = Color(hex: draft.accentHex)
        Button { draft.type = type } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(selected ? accent : DesignTokens.Surface.inactive)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle().strokeBorder(selected ? accent.darker(by: 0.2) : DesignTokens.Surface.hairline(), lineWidth: 1)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.custom(FontFamily.sans, size: 14))
                        .fontWeight(.semibold)
                        .foregroundColor(selected ? accent : DesignTokens.Surface.fg())
                    Text(subtitle)
                        .font(.custom(FontFamily.sans, size: 12))
                        .foregroundColor(DesignTokens.Surface.mutedText)
                }
                Spacer()
            }
            .padding(12)
            .background(DesignTokens.Surface.card)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selected ? accent.opacity(0.5) : DesignTokens.Surface.hairline(), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
