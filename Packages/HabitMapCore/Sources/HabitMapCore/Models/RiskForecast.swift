import Foundation

public enum RiskLevel: Int, Sendable, Comparable {
    case noData = 0
    case completed4 = 1
    case completed3 = 2
    case completed2 = 3
    case completed1 = 4
    case warn = 5
    case danger = 6

    public static func < (a: RiskLevel, b: RiskLevel) -> Bool { a.rawValue < b.rawValue }
}

public struct RiskForecast: Sendable, Equatable {
    public let matrix: [[RiskLevel]]
    public let topRisks: [RiskWindow]

    public init(matrix: [[RiskLevel]], topRisks: [RiskWindow]) {
        self.matrix = matrix
        self.topRisks = topRisks
    }

    public static let empty = RiskForecast(
        matrix: Array(repeating: Array(repeating: RiskLevel.noData, count: 8), count: 7),
        topRisks: []
    )
}

public struct RiskWindow: Sendable, Equatable {
    public let weekday: Int
    public let bucket: Int
    public let level: RiskLevel
    public let attempts: Int

    public init(weekday: Int, bucket: Int, level: RiskLevel, attempts: Int) {
        self.weekday = weekday
        self.bucket = bucket
        self.level = level
        self.attempts = attempts
    }
}
