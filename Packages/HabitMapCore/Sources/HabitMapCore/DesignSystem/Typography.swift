import SwiftUI

public enum Typography {
    public enum Size: CGFloat, Sendable, CaseIterable {
        case caption = 10
        case footnote = 12
        case body = 14
        case heading = 16
        case title = 20

        public var tracking: CGFloat {
            switch self {
            case .caption: return 1.2
            case .footnote: return 1.0
            case .body: return 0.6
            case .heading: return 0.4
            case .title: return 0.2
            }
        }
    }

    public enum Weight: Sendable {
        case regular, medium, heavy

        public var swiftUI: Font.Weight {
            switch self {
            case .regular: return .regular
            case .medium: return .medium
            case .heavy: return .heavy
            }
        }
    }
}
