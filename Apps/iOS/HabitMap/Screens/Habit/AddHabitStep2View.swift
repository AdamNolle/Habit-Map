import SwiftUI
import HabitMapCore

struct AddHabitStep2View: View {
    @Binding var draft: WizardDraft
    let pageAccent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            PixelText("STEP 2 - HOW OFTEN", pixelSize: 2, color: DesignTokens.Surface.mutedText)

            VStack(alignment: .leading, spacing: 12) {
                PixelText("TYPE", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                typeRow(.manualOnce, label: "ONCE A DAY", subtitle: "Tap once when done")
                typeRow(.manualMultiple, label: "MULTIPLE TIMES", subtitle: "Tap N times to hit target")
                typeRow(.inverse, label: "AVOID", subtitle: "Default complete unless slipped")
            }

            if draft.type == .manualMultiple {
                VStack(alignment: .leading, spacing: 10) {
                    PixelText("TARGET REPS", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                    HStack(spacing: DesignTokens.Spacing.md) {
                        PixelButton("-", style: .secondary, accent: Color(hex: draft.accentHex)) {
                            draft.targetReps = max(1, draft.targetReps - 1)
                        }.frame(width: 60)
                        PixelText("\(draft.targetReps)", pixelSize: 6, color: Color(hex: draft.accentHex))
                            .frame(maxWidth: .infinity)
                        PixelButton("+", style: .secondary, accent: Color(hex: draft.accentHex)) {
                            draft.targetReps = min(20, draft.targetReps + 1)
                        }.frame(width: 60)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func typeRow(_ type: HabitType, label: String, subtitle: String) -> some View {
        Button { draft.type = type } label: {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(draft.type == type ? Color(hex: draft.accentHex) : DesignTokens.Surface.inactive)
                    .frame(width: 18, height: 18)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    PixelText(label, pixelSize: 2, color: Color(hex: draft.accentHex))
                    Text(subtitle)
                        .font(.system(.caption2, design: .monospaced).weight(.heavy))
                        .tracking(1.0)
                        .foregroundColor(DesignTokens.Surface.mutedText)
                }
                Spacer()
            }
            .padding(12)
            .background(DesignTokens.Surface.card)
            .overlay(Rectangle().stroke(draft.type == type ? Color(hex: draft.accentHex) : DesignTokens.Surface.cardBorder,
                                       lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(draft.type == type ? [.isButton, .isSelected] : .isButton)
    }
}
