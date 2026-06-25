import Foundation
import SwiftData
import SwiftUI

@Model
public final class Habit {
    public var id: UUID = UUID()
    public var name: String = ""
    public var emoji: String = ""
    public var accentHex: String = "#2BFF5F"
    public var typeRaw: String = HabitType.manualOnce.rawValue
    public var targetReps: Int = 1
    public var healthMetricRaw: String?
    public var healthGoal: Double?
    public var weekdayMask: Int8 = 0b01111111
    public var restDayMask: Int8 = 0
    public var reminderTime: Date?
    public var isPaused: Bool = false
    public var isArchived: Bool = false
    public var sortOrder: Int = 0
    public var createdAt: Date = Date()

    public var page: HabitPage?

    @Relationship(deleteRule: .cascade, inverse: \HabitCompletion.habit)
    public var completions: [HabitCompletion]? = []

    public init(id: UUID = UUID(),
                name: String,
                emoji: String,
                accentHex: String,
                type: HabitType,
                targetReps: Int,
                weekdayMask: Int8 = 0b01111111,
                restDayMask: Int8 = 0,
                sortOrder: Int = 0,
                page: HabitPage? = nil,
                createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.accentHex = accentHex
        self.typeRaw = type.rawValue
        self.targetReps = targetReps
        self.weekdayMask = weekdayMask
        self.restDayMask = restDayMask
        self.isPaused = false
        self.isArchived = false
        self.sortOrder = sortOrder
        self.page = page
        self.createdAt = createdAt
    }

    public var type: HabitType {
        get { HabitType(rawValue: typeRaw) ?? .manualOnce }
        set { typeRaw = newValue.rawValue }
    }

    public var healthMetric: HealthMetric? {
        get { healthMetricRaw.flatMap(HealthMetric.init(rawValue:)) }
        set { healthMetricRaw = newValue?.rawValue }
    }

    public var accentColor: Color { Color(hex: accentHex) }

    // MARK: - Completion lookups

    public func completion(on date: Date) -> HabitCompletion? {
        let start = Calendar.current.startOfDay(for: date)
        return (completions ?? []).first { Calendar.current.isDate($0.date, inSameDayAs: start) }
    }

    // MARK: - Schedule

    public func isRestDay(_ date: Date) -> Bool {
        let weekday = (Calendar.current.component(.weekday, from: date) + 5) % 7
        return (restDayMask & Int8(1 << weekday)) != 0
    }

    public func isScheduled(_ date: Date) -> Bool {
        let weekday = (Calendar.current.component(.weekday, from: date) + 5) % 7
        return (weekdayMask & Int8(1 << weekday)) != 0 && !isRestDay(date)
    }

    /// The earliest day this habit can count toward stats: the start-of-day of the
    /// earlier of `createdAt` and the habit's earliest logged completion. Days before
    /// this floor predate the habit and must not count as "scheduled but missed".
    public var activeSince: Date {
        let cal = Calendar.current
        let creation = cal.startOfDay(for: createdAt)
        guard let earliestCompletion = (completions ?? [])
            .map({ cal.startOfDay(for: $0.date) })
            .min() else { return creation }
        return min(creation, earliestCompletion)
    }

    /// True when `date` is scheduled AND on/after the habit's `activeSince` floor.
    public func isActive(on date: Date) -> Bool {
        isScheduled(date) && Calendar.current.startOfDay(for: date) >= activeSince
    }

    // MARK: - Progress

    public func progressFraction(on date: Date) -> Double {
        switch type {
        case .manualOnce:
            return (completion(on: date)?.reps ?? 0) >= 1 ? 1.0 : 0.0
        case .manualMultiple:
            let reps = completion(on: date)?.reps ?? 0
            return min(Double(reps) / Double(max(targetReps, 1)), 1.0)
        case .autoHealth:
            let reps = completion(on: date)?.reps ?? 0
            let goal = healthGoal ?? Double(max(targetReps, 1))
            guard goal > 0 else { return reps > 0 ? 1.0 : 0.0 }
            return min(Double(reps) / goal, 1.0)
        case .inverse:
            return (completion(on: date)?.slipped ?? false) ? 0.0 : 1.0
        }
    }

    public func cellLevel(on date: Date) -> CellLevel {
        if date > Date() { return .future }
        if isRestDay(date) { return .rest }
        if type == .inverse, completion(on: date)?.slipped == true { return .miss }
        return CellLevel.from(progress: progressFraction(on: date))
    }

    // MARK: - Recovery rate (spec §11.3)

    public func recoveryRate(window: Int = 30, asOf: Date = Date()) -> Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        var expected = 0
        var achieved = 0
        for offset in 0..<window {
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            guard isScheduled(d) else { continue }
            expected += 1
            if progressFraction(on: d) >= 1.0 { achieved += 1 }
        }
        guard expected > 0 else { return 1.0 }
        return Double(achieved) / Double(expected)
    }
}
