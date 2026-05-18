import SwiftUI

/// Small pulsing indicator dot. Used in eyebrows for "live" markers.
public struct Pip: View {
    let color: Color
    let size: CGFloat
    @State private var phase: Double = 1.0

    public init(color: Color = DesignTokens.Accent.classicGreen, size: CGFloat = 6) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.45), radius: size * 0.5)
            .opacity(phase)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    phase = 0.45
                }
            }
    }
}
