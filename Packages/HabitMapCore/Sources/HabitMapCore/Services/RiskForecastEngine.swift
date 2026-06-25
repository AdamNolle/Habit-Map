import Foundation

@MainActor
public final class RiskForecastEngine {
    public init() {}

    public func forecast(habits: [Habit], asOf: Date = Date()) -> RiskForecast {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        var buckets: [[(attempts: Int, skips: Int)]] =
            Array(repeating: Array(repeating: (0, 0), count: 8), count: 7)

        for habit in habits where !habit.isArchived && !habit.isPaused {
            let expectedBucket = InsightsEngine.expectedBucket(for: habit, cal: cal)
            for offset in 1..<30 {
                guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                guard habit.isScheduled(day) else { continue }
                let wd = (cal.component(.weekday, from: day) + 5) % 7
                let completed = habit.progressFraction(on: day) >= 1.0
                let completion = habit.completion(on: day)
                let bucket: Int
                if completed, let logged = completion?.loggedAt {
                    bucket = InsightsEngine.bucketIndex(for: logged, cal: cal)
                } else if let expectedBucket {
                    // Skipped day → attribute to the habit's expected time column,
                    // not the "overnight" sentinel.
                    bucket = expectedBucket
                } else {
                    continue  // No signal for when this habit belongs — leave it out of the matrix.
                }
                buckets[wd][bucket].attempts += 1
                if !completed { buckets[wd][bucket].skips += 1 }
            }
        }

        var matrix = Array(repeating: Array(repeating: RiskLevel.noData, count: 8), count: 7)
        var allWindows: [RiskWindow] = []
        for wd in 0..<7 {
            for bucket in 0..<8 {
                let entry = buckets[wd][bucket]
                guard entry.attempts >= 4 else { continue }
                let skipRate = Double(entry.skips) / Double(entry.attempts)
                let level: RiskLevel
                switch skipRate {
                case 0.80...:  level = .danger
                case 0.65...:  level = .warn
                case 0.50...:  level = .completed1
                case 0.35...:  level = .completed2
                case 0.20...:  level = .completed3
                default:       level = .completed4
                }
                matrix[wd][bucket] = level
                allWindows.append(RiskWindow(weekday: wd, bucket: bucket, level: level, attempts: entry.attempts))
            }
        }
        let topRisks = allWindows
            .filter { $0.level >= .warn }
            .sorted { $0.level > $1.level }
            .prefix(3)
        return RiskForecast(matrix: matrix, topRisks: Array(topRisks))
    }
}
