import SwiftUI

public struct EmojiPicker: View {
    @Binding var selected: String
    let accent: Color

    public static let catalog: [String] = [
        // Health
        "💧", "🏃", "🚶", "🧘", "🏋️", "🚴", "🏊", "🥗",
        "🍎", "🥦", "💊", "🧴", "🦷", "💤", "🛏️", "☀️",
        // Mind
        "📖", "✍️", "🧠", "🎯", "💭", "🕯️", "🎨", "🎵",
        // Work
        "💻", "📧", "📞", "📊", "📁", "✅", "🗓️", "⏰",
        // Home
        "🧹", "🍽️", "🧺", "🪴", "🐕", "🐈", "👨‍👩‍👧", "💌",
        // Fun
        "🎮", "🎬", "🎤", "🎉", "🎸", "🧩", "📷", "✈️",
        // Vices
        "🚬", "🍷", "🥤", "🍰", "📱", "📺", "🛍️", "🎰",
        // Generic
        "⭐", "❤️", "🔥", "💎", "🏆", "🌱", "🌊", "🌙"
    ]

    public init(selected: Binding<String>, accent: Color = DesignTokens.Accent.classicGreen) {
        self._selected = selected
        self.accent = accent
    }

    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
            ForEach(Self.catalog, id: \.self) { emoji in
                Button(action: { selected = emoji }) {
                    Text(emoji)
                        .font(.system(size: 22))
                        .frame(width: 36, height: 36)
                        .background(selected == emoji ? accent.darker(by: 0.4) : DesignTokens.Surface.tile)
                        .overlay(Rectangle().stroke(selected == emoji ? accent : DesignTokens.Surface.tileBorder,
                                                   lineWidth: selected == emoji ? 2 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(emoji)
                .accessibilityAddTraits(selected == emoji ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}
