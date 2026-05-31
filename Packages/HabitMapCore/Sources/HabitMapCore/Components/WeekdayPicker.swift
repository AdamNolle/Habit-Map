import SwiftUI

public struct WeekdayPicker: View {
    @Binding var mask: Int8
    let accent: Color
    @EnvironmentObject private var haptics: Haptics
    let labels: [String] = ["M", "T", "W", "T", "F", "S", "S"]

    public init(mask: Binding<Int8>, accent: Color = DesignTokens.Accent.classicGreen) {
        self._mask = mask
        self.accent = accent
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { idx in
                let bit = Int8(1 << idx)
                let isOn = (mask & bit) != 0
                Button(action: { haptics.selection(); mask ^= bit }) {
                    PixelText(labels[idx], pixelSize: 2, color: isOn ? .black : accent)
                        .frame(width: 28, height: 28)
                        .background(isOn ? accent : DesignTokens.Surface.tile)
                        .overlay(Rectangle().stroke(isOn ? accent.darker(by: 0.2) : DesignTokens.Surface.tileBorder,
                                                   lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][idx])
                .accessibilityValue(isOn ? "selected" : "not selected")
                .accessibilityAddTraits(.isButton)
            }
        }
    }
}
