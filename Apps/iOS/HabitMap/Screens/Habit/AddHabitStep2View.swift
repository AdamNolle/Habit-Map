import SwiftUI
import HealthKit
import HabitMapCore

struct AddHabitStep2View: View {
    @Binding var draft: WizardDraft
    let pageAccent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            MonoText("STEP 2 — HOW OFTEN", size: .caption, weight: .heavy,
                     color: DesignTokens.Surface.mutedText)

            VStack(alignment: .leading, spacing: 8) {
                MonoText.label("TYPE")
                typeRow(.manualOnce, label: "ONCE A DAY", subtitle: "Tap once when done")
                typeRow(.manualMultiple, label: "MULTIPLE TIMES", subtitle: "Tap N times to hit target")
                typeRow(.inverse, label: "AVOID", subtitle: "Default complete unless slipped")
                if HKHealthStore.isHealthDataAvailable() {
                    typeRow(.autoHealth, label: "AUTO-FILL FROM HEALTH", subtitle: "Apple Health populates progress")
                }
            }

            if draft.type == .manualMultiple {
                VStack(alignment: .leading, spacing: 8) {
                    MonoText.label("TARGET REPS")
                    HStack(spacing: DesignTokens.Spacing.md) {
                        PixelButton("−", style: .secondary, accent: Color(hex: draft.accentHex)) {
                            draft.targetReps = max(1, draft.targetReps - 1)
                        }.frame(width: 56)
                        MonoText("\(draft.targetReps)", size: .title, weight: .heavy,
                                 color: Color(hex: draft.accentHex))
                            .frame(maxWidth: .infinity)
                        PixelButton("+", style: .secondary, accent: Color(hex: draft.accentHex)) {
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
        Button { draft.type = type } label: {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(draft.type == type ? Color(hex: draft.accentHex) : DesignTokens.Surface.inactive)
                    .frame(width: 16, height: 16)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    MonoText(label, size: .footnote, weight: .heavy,
                             color: Color(hex: draft.accentHex))
                    MonoText(subtitle, size: .caption, weight: .regular,
                             color: DesignTokens.Surface.mutedText)
                }
                Spacer()
            }
            .padding(10)
            .background(DesignTokens.Surface.card)
            .overlay(Rectangle().stroke(draft.type == type ? Color(hex: draft.accentHex) : DesignTokens.Surface.cardBorder,
                                       lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(draft.type == type ? [.isButton, .isSelected] : .isButton)
    }
}
