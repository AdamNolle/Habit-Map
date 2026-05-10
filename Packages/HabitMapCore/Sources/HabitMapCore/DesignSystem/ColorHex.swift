import SwiftUI
import UIKit

public extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard trimmed.count == 6 || trimmed.count == 8,
              let value = UInt64(trimmed, radix: 16) else {
            self = .clear
            return
        }
        let r, g, b, a: Double
        if trimmed.count == 6 {
            r = Double((value & 0xFF0000) >> 16) / 255.0
            g = Double((value & 0x00FF00) >> 8) / 255.0
            b = Double(value & 0x0000FF) / 255.0
            a = 1.0
        } else {
            r = Double((value & 0xFF000000) >> 24) / 255.0
            g = Double((value & 0x00FF0000) >> 16) / 255.0
            b = Double((value & 0x0000FF00) >> 8) / 255.0
            a = Double(value & 0x000000FF) / 255.0
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    var rgbaComponents: (r: Double, g: Double, b: Double, a: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }

    func lighter(by amount: Double) -> Color {
        let c = rgbaComponents
        return Color(.sRGB,
                     red: min(c.r + amount, 1.0),
                     green: min(c.g + amount, 1.0),
                     blue: min(c.b + amount, 1.0),
                     opacity: c.a)
    }

    func darker(by amount: Double) -> Color {
        let c = rgbaComponents
        return Color(.sRGB,
                     red: max(c.r - amount, 0.0),
                     green: max(c.g - amount, 0.0),
                     blue: max(c.b - amount, 0.0),
                     opacity: c.a)
    }
}
