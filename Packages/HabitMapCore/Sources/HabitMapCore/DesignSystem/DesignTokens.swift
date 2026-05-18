import SwiftUI

/// v5 design tokens — Apple-Design-Awards aesthetic.
/// Hand-tuned for both dark and light themes. Most tokens are theme-aware via
/// `ColorScheme` parameter; convenience defaults (`.bg`, `.card`, etc.) resolve
/// to dark-theme values for legacy call sites.
public enum DesignTokens {

    // MARK: - Surfaces

    public enum Surface {
        public static func bg(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color(hex: "#0A0C0B") : Color(hex: "#F7F5EF")
        }
        public static func bgElev(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color(hex: "#11141A") : Color(hex: "#FFFFFF")
        }
        public static func card(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color(hex: "#0F1318") : Color(hex: "#FFFFFF")
        }
        public static func deep(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color(hex: "#07090A") : Color(hex: "#EFEDE5")
        }
        public static func line(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color(hex: "#1F262C") : Color(hex: "#DDDCD3")
        }
        public static func lineStrong(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color(hex: "#2E363D") : Color(hex: "#B4B3AA")
        }
        public static func hairline(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color.white.opacity(0.055) : Color.black.opacity(0.085)
        }
        public static func hairlineStrong(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.16)
        }
        public static func tint0(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color.white.opacity(0.018) : Color.black.opacity(0.025)
        }
        public static func tint1(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color.white.opacity(0.035) : Color.black.opacity(0.045)
        }
        public static func tint2(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color.white.opacity(0.055) : Color.black.opacity(0.07)
        }
        public static func tint3(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color.white.opacity(0.085) : Color.black.opacity(0.11)
        }
        public static func fg(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color(hex: "#F1F0EA") : Color(hex: "#0C100D")
        }
        public static func fgDim(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color(hex: "#A8ADA6") : Color(hex: "#3A3D38")
        }
        public static func fgMute(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color(hex: "#82877E") : Color(hex: "#696C63")
        }
        public static func fgFaint(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color(hex: "#555A53") : Color(hex: "#9A9D93")
        }

        // Convenience defaults (dark) for legacy call sites
        public static let bg          = Color(hex: "#0A0C0B")
        public static let bgElev      = Color(hex: "#11141A")
        public static let card        = Color(hex: "#0F1318")
        public static let cardBorder  = Color(hex: "#1F262C")
        public static let tile        = Color(hex: "#11141A")
        public static let tileBorder  = Color(hex: "#2E363D")
        public static let inactive    = Color(hex: "#1F262C")
        public static let future      = Color(hex: "#0F1318")
        public static let futureBorder = Color(hex: "#2E363D")
        public static let rest        = Color(hex: "#0F1318")
        public static let restBorder  = Color(hex: "#5C73C7")
        public static let miss        = Color(hex: "#FF6B6B")
        public static let mutedText   = Color(hex: "#82877E")
        public static let dimText     = Color(hex: "#555A53")
        public static let dotInactive = Color(hex: "#2E363D")
    }

    // MARK: - Accents (FILLS stay vivid in both modes)

    public enum Accent {
        public static let classicGreen = Color(hex: "#3DFF7F")
        public static let lime         = Color(hex: "#C8FF2B")
        public static let cobalt       = Color(hex: "#3DA4FF")
        public static let sunrise      = Color(hex: "#FFB23D")
        public static let lilac        = Color(hex: "#C77BFF")
        public static let rose         = Color(hex: "#FF6B9A")
        public static let ice          = Color(hex: "#7EE6FF")
        public static let cbBlue       = Color(hex: "#0072B2")
        public static let cbAmber      = Color(hex: "#E69F00")
    }

    // MARK: - Semantic colors

    public enum Semantic {
        public static func ai(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color(hex: "#B19BCE") : Color(hex: "#6B4A99")
        }
        public static func info(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color(hex: "#A0E2EA") : Color(hex: "#1E7E92")
        }
        public static func delight(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color(hex: "#F2A6C0") : Color(hex: "#A53A6A")
        }
        public static func warn(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color(hex: "#FFCC33") : Color(hex: "#8F6300")
        }
        public static func danger(_ scheme: ColorScheme = .dark) -> Color {
            scheme == .dark ? Color(hex: "#FF6B6B") : Color(hex: "#A82828")
        }
        // Dark defaults for direct property access
        public static let ai      = Color(hex: "#B19BCE")
        public static let info    = Color(hex: "#A0E2EA")
        public static let delight = Color(hex: "#F2A6C0")
        public static let warn    = Color(hex: "#FFCC33")
        public static let danger  = Color(hex: "#FF6B6B")
    }

    // MARK: - Spacing scale

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 10
        public static let lg: CGFloat = 14
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 28
    }

    // MARK: - Radius scale

    public enum Radius {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 7
        public static let md: CGFloat = 11
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 22
        public static let pill: CGFloat = 999
    }
}

// MARK: - Tonal accent remapping

public extension Color {
    /// Returns a contrast-tuned variant of an accent hex for the active scheme.
    /// Used on text/borders. Fills should keep the raw vivid accent.
    static func tonalAccent(_ hex: String, scheme: ColorScheme) -> Color {
        guard scheme == .light else { return Color(hex: hex) }
        let lower = hex.lowercased()
        let map: [String: String] = [
            "#2bff5f": "#1F7A3E", "#3dff7f": "#1F7A3E",
            "#3da4ff": "#0865B0",
            "#ffb23d": "#8F6300", "#ffcc33": "#8F6300",
            "#c77bff": "#6B4A99", "#b19bce": "#6B4A99",
            "#ff6b9a": "#A53A6A", "#f2a6c0": "#A53A6A",
            "#7ee6ff": "#1E7E92", "#a0e2ea": "#1E7E92",
            "#c8ff2b": "#5A7300",
            "#ff6b6b": "#A82828"
        ]
        return Color(hex: map[lower] ?? hex)
    }
}
