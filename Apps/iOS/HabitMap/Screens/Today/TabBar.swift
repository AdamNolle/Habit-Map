import SwiftUI
import HabitMapCore

public enum HabitMapTab: String, CaseIterable {
    case today, map, stats, setup
}

struct TabBar: View {
    let active: HabitMapTab
    let onSelect: (HabitMapTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            tab(.today, icon: .home,  label: "TODAY")
            tab(.map,   icon: .grid,  label: "MAP")
            tab(.stats, icon: .chart, label: "STATS")
            tab(.setup, icon: .gear,  label: "SETUP")
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(DesignTokens.Surface.bg)
        .overlay(Rectangle().fill(DesignTokens.Surface.cardBorder).frame(height: 1), alignment: .top)
    }

    private func tab(_ tab: HabitMapTab, icon: PixelIconName, label: String) -> some View {
        let color = (active == tab) ? Color(hex: "#2BFF5F") : DesignTokens.Surface.dimText
        return Button {
            onSelect(tab)
        } label: {
            VStack(spacing: 4) {
                PixelIcon(icon, color: color, size: 24)
                PixelText(label, pixelSize: 2, color: color)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) tab")
        .accessibilityAddTraits(active == tab ? [.isButton, .isSelected] : .isButton)
    }
}
