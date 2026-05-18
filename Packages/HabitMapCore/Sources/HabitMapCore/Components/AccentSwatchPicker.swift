import SwiftUI

public struct AccentSwatchPicker: View {
    @Binding var selectedHex: String
    @EnvironmentObject private var haptics: Haptics

    public static let swatches: [String] = [
        "#2BFF5F", "#C8FF2B", "#3DA4FF",
        "#FFB23D", "#C77BFF", "#FF6B9A",
        "#7EE6FF", "#0072B2", "#E69F00"
    ]

    public init(selectedHex: Binding<String>) {
        self._selectedHex = selectedHex
    }

    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(Self.swatches, id: \.self) { hex in
                let color = Color(hex: hex)
                Button(action: { haptics.selection(); selectedHex = hex }) {
                    Rectangle()
                        .fill(color)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Rectangle()
                                .stroke(selectedHex == hex ? Color.white : color.darker(by: 0.25),
                                        lineWidth: selectedHex == hex ? 3 : 2)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Color \(hex)")
                .accessibilityAddTraits(selectedHex == hex ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}
