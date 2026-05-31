import SwiftUI

/// Lock-screen face for the steps Live Activity. Pure SwiftUI over plain values
/// (no ActivityKit), so it's reusable by the extension's `ActivityConfiguration`
/// and snapshot-testable on its own.
public struct StepsActivityView: View {
    let habitName: String
    let accentHex: String
    let current: Int
    let goal: Int

    public init(habitName: String, accentHex: String, current: Int, goal: Int) {
        self.habitName = habitName
        self.accentHex = accentHex
        self.current = current
        self.goal = goal
    }

    private var accent: Color { Color(hex: accentHex) }
    private var fraction: Double { goal > 0 ? min(Double(current) / Double(goal), 1.0) : 0 }
    private var isComplete: Bool { goal > 0 && current >= goal }

    public var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(DesignTokens.Surface.hairline(), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(fraction * 100))")
                    .font(.custom(FontFamily.mono, size: 13))
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundColor(accent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(habitName.titleCased)
                    .font(.custom(FontFamily.sans, size: 15))
                    .fontWeight(.semibold)
                    .foregroundColor(DesignTokens.Surface.fg())
                Text(isComplete ? "Goal reached" : "\(current) / \(goal) steps")
                    .font(.custom(FontFamily.mono, size: 12))
                    .monospacedDigit()
                    .foregroundColor(DesignTokens.Surface.mutedText)
            }
            Spacer(minLength: 0)
            Pip(color: isComplete ? accent : DesignTokens.Surface.mutedText, size: 8)
        }
        .padding(16)
        .background(DesignTokens.Surface.bg)
    }
}
