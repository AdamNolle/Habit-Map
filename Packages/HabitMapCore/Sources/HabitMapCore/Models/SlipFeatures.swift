import Foundation

/// Snapshot of one user's recent habit behavior — the input the coach reasons about.
public struct SlipFeatures: Sendable, Equatable, Codable {
    public let windowDays: Int
    public let totalScheduled: Int
    public let totalCompleted: Int
    public let consistencyPct: Double

    public let perHabit: [HabitFeatures]
    public let weekdayCompletion: [Double]    // 7 entries, Mon..Sun, 0..1
    public let topSlipWindows: [SlipWindow]
    public let idleHabits: [String]
    public let strongPairs: [HabitPair]
    public let recoveryDaysAverage: Double    // average days to bounce back after a miss
    public let streakBreakSignals: [String]

    public init(windowDays: Int,
                totalScheduled: Int,
                totalCompleted: Int,
                consistencyPct: Double,
                perHabit: [HabitFeatures],
                weekdayCompletion: [Double],
                topSlipWindows: [SlipWindow],
                idleHabits: [String],
                strongPairs: [HabitPair],
                recoveryDaysAverage: Double,
                streakBreakSignals: [String]) {
        self.windowDays = windowDays
        self.totalScheduled = totalScheduled
        self.totalCompleted = totalCompleted
        self.consistencyPct = consistencyPct
        self.perHabit = perHabit
        self.weekdayCompletion = weekdayCompletion
        self.topSlipWindows = topSlipWindows
        self.idleHabits = idleHabits
        self.strongPairs = strongPairs
        self.recoveryDaysAverage = recoveryDaysAverage
        self.streakBreakSignals = streakBreakSignals
    }

    public static let empty = SlipFeatures(
        windowDays: 30, totalScheduled: 0, totalCompleted: 0, consistencyPct: 0,
        perHabit: [], weekdayCompletion: Array(repeating: 0, count: 7),
        topSlipWindows: [], idleHabits: [], strongPairs: [],
        recoveryDaysAverage: 0, streakBreakSignals: []
    )

    public var isLearning: Bool {
        // Fewer than 7 days of any data — coach should soft-pedal.
        totalCompleted < 3 && totalScheduled < 7
    }
}

public struct HabitFeatures: Sendable, Equatable, Codable {
    public let id: UUID
    public let name: String
    public let typeRaw: String
    public let consistency30d: Double
    public let bestWeekday: Int?
    public let worstWeekday: Int?
    public let daysSinceLastLog: Int

    public init(id: UUID, name: String, typeRaw: String,
                consistency30d: Double,
                bestWeekday: Int?, worstWeekday: Int?,
                daysSinceLastLog: Int) {
        self.id = id
        self.name = name
        self.typeRaw = typeRaw
        self.consistency30d = consistency30d
        self.bestWeekday = bestWeekday
        self.worstWeekday = worstWeekday
        self.daysSinceLastLog = daysSinceLastLog
    }
}

public struct SlipWindow: Sendable, Equatable, Codable {
    public let weekday: Int          // 0=Mon ... 6=Sun
    public let bucketHour: Int       // 6, 9, 12, 15, 18, 21, 0, 3
    public let skipRate: Double      // 0..1
    public let attempts: Int

    public init(weekday: Int, bucketHour: Int, skipRate: Double, attempts: Int) {
        self.weekday = weekday
        self.bucketHour = bucketHour
        self.skipRate = skipRate
        self.attempts = attempts
    }
}

public struct HabitPair: Sendable, Equatable, Codable {
    public let a: String
    public let b: String
    public let coOccurrenceRate: Double

    public init(a: String, b: String, coOccurrenceRate: Double) {
        self.a = a
        self.b = b
        self.coOccurrenceRate = coOccurrenceRate
    }
}
