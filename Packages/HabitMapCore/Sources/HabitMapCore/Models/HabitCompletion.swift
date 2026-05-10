import Foundation
import SwiftData

@Model
public final class HabitCompletion {
    public var id: UUID = UUID()
    public var date: Date = Date()
    public var reps: Int = 0
    public var slipped: Bool = false
    public var note: String?
    public var loggedAt: Date = Date()
    public var sourceRaw: String = CompletionSource.manual.rawValue

    public var habit: Habit?

    public init(id: UUID = UUID(),
                date: Date,
                reps: Int = 0,
                slipped: Bool = false,
                note: String? = nil,
                loggedAt: Date = Date(),
                source: CompletionSource = .manual,
                habit: Habit? = nil) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.reps = reps
        self.slipped = slipped
        self.note = note
        self.loggedAt = loggedAt
        self.sourceRaw = source.rawValue
        self.habit = habit
    }

    public var source: CompletionSource {
        get { CompletionSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    public var isComplete: Bool {
        guard let habit else { return reps > 0 }
        return habit.progressFraction(on: date) >= 1.0
    }
}

public extension Date {
    static func startOfToday() -> Date {
        Calendar.current.startOfDay(for: Date())
    }
}
