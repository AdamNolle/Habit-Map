import SwiftUI

public struct PixelToggle: View {
    @Binding var isOn: Bool
    let accent: Color

    public init(isOn: Binding<Bool>, accent: Color = DesignTokens.Accent.classicGreen) {
        self._isOn = isOn
        self.accent = accent
    }

    public var body: some View {
        Button(action: { isOn.toggle() }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Rectangle()
                    .fill(isOn ? accent.darker(by: 0.2) : DesignTokens.Surface.tile)
                    .overlay(Rectangle().stroke(isOn ? accent : DesignTokens.Surface.tileBorder, lineWidth: 2))
                    .frame(width: 44, height: 24)
                Rectangle()
                    .fill(isOn ? accent : DesignTokens.Surface.inactive)
                    .frame(width: 16, height: 16)
                    .padding(4)
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "on" : "off")
        .accessibilityAddTraits(.isButton)
    }
}
