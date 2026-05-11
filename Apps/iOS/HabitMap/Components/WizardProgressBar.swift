import SwiftUI
import HabitMapCore

struct WizardProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { idx in
                Rectangle()
                    .fill(idx == currentStep
                          ? accent
                          : (idx < currentStep ? accent.darker(by: 0.4) : DesignTokens.Surface.dotInactive))
                    .frame(height: 6)
                    .overlay(Rectangle().stroke(.black, lineWidth: 1))
            }
        }
    }
}
