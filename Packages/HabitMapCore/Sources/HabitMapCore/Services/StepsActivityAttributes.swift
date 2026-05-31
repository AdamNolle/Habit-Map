import Foundation

#if os(iOS)
import ActivityKit

/// Live Activity for one in-progress `.autoHealth` (steps) habit. Defined in the
/// package so the app (which starts/updates activities) and the widget extension
/// (which renders them) share the type.
///
/// Runtime rendering requires a physical device — the lock-screen / Dynamic Island
/// surfaces don't appear in the simulator. The view + content state are still
/// unit- and snapshot-tested via `StepsActivityView`.
public struct StepsActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var current: Int
        public var goal: Int

        public init(current: Int, goal: Int) {
            self.current = current
            self.goal = goal
        }

        public var fraction: Double {
            goal > 0 ? min(Double(current) / Double(goal), 1.0) : 0
        }

        public var isComplete: Bool { goal > 0 && current >= goal }
    }

    public var habitName: String
    public var accentHex: String

    public init(habitName: String, accentHex: String) {
        self.habitName = habitName
        self.accentHex = accentHex
    }
}
#endif
