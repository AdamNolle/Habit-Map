import SwiftUI

public enum Typography {
    public enum Size: CGFloat, Sendable, CaseIterable {
        case caption = 10
        case footnote = 12
        case body = 14
        case heading = 16
        case title = 20
        case display1 = 28
        case display2 = 36
        case display3 = 48

        public var tracking: CGFloat {
            switch self {
            case .caption: return 1.2
            case .footnote: return 1.0
            case .body: return 0.6
            case .heading: return 0.4
            case .title: return 0.2
            case .display1, .display2, .display3: return -0.6
            }
        }
    }

    public enum Weight: Sendable {
        case regular, medium, semibold, heavy

        public var swiftUI: Font.Weight {
            switch self {
            case .regular:  return .regular
            case .medium:   return .medium
            case .semibold: return .semibold
            case .heavy:    return .heavy
            }
        }
    }
}

/// Bundled font family names. Match the PostScript names embedded in the .ttf files.
public enum FontFamily {
    public static let serif = "InstrumentSerif-Regular"
    public static let serifItalic = "InstrumentSerif-Italic"
    public static let sans = "Inter-Regular"
    public static let mono = "JetBrainsMono-Regular"
    public static let pixel = "Silkscreen-Regular"
}
