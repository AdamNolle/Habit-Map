import SwiftUI

/// Tab identifiers. The custom pixel-art TabBar was retired in Plan 07 in favor
/// of the native SwiftUI `TabView` (Liquid Glass on iOS 18+). This enum stays so
/// other code can reference tabs by name (e.g. notification-tap routing).
public enum HabitMapTab: String, CaseIterable, Sendable {
    case today, map, stats, setup
}
