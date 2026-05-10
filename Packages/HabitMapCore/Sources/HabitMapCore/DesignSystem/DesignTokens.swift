import SwiftUI

public enum DesignTokens {
    public enum Surface {
        public static let bg          = Color(hex: "#0A0A0A")
        public static let card        = Color(hex: "#141414")
        public static let cardBorder  = Color(hex: "#1F1F1F")
        public static let tile        = Color(hex: "#0F0F0F")
        public static let tileBorder  = Color(hex: "#2A2A2A")
        public static let inactive    = Color(hex: "#383838")
        public static let future      = Color(hex: "#171717")
        public static let futureBorder = Color(hex: "#303030")
        public static let rest        = Color(hex: "#161616")
        public static let restBorder  = Color(hex: "#5C73C7")
        public static let miss        = Color(hex: "#FF4D4D")
        public static let mutedText   = Color(hex: "#808073")
        public static let dimText     = Color(hex: "#5A5A55")
        public static let dotInactive = Color(hex: "#3A3A3A")
    }

    public enum Accent {
        public static let classicGreen = Color(hex: "#2BFF5F")
        public static let lime         = Color(hex: "#C8FF2B")
        public static let cobalt       = Color(hex: "#3DA4FF")
        public static let sunrise      = Color(hex: "#FFB23D")
        public static let lilac        = Color(hex: "#C77BFF")
        public static let rose         = Color(hex: "#FF6B9A")
        public static let ice          = Color(hex: "#7EE6FF")
        public static let cbBlue       = Color(hex: "#0072B2")
        public static let cbAmber      = Color(hex: "#E69F00")
    }

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 10
        public static let lg: CGFloat = 14
        public static let xl: CGFloat = 20
    }
}
