import Foundation

/// Templated coach. Picks the highest-priority insight category, fills in a
/// human-readable paragraph and (when relevant) an actionable suggestion.
/// Output passes through `NotificationCopy.assertSafe(_:tone:)` to keep gentle.
public final class RuleBasedCoach: HabitCoachEngine {
    public var supportsFreeFormChat: Bool { false }

    public init() {}

    public func coach(features: SlipFeatures) async throws -> CoachInsight {
        if features.isLearning {
            return .learning
        }
        return makeInsight(from: features)
    }

    public func answer(question: String, features: SlipFeatures) async throws -> String {
        // Keyword routing — limited but useful enough to be helpful.
        let q = question.lowercased()
        if q.contains("slip") || q.contains("miss") || q.contains("when") {
            if let win = features.topSlipWindows.first {
                let day = SlipFeatureExtractor.weekdayName(win.weekday)
                let time = SlipFeatureExtractor.formatHour(win.bucketHour)
                return "Your biggest slip window lately is \(day) around \(time) — \(Int(win.skipRate * 100))% skip rate over \(win.attempts) attempts."
            }
        }
        if q.contains("idle") || q.contains("quiet") {
            if let first = features.idleHabits.first {
                return "\(first.capitalized) has been quiet for a while. You can pause it from the habit's detail view if it's not serving you right now."
            }
        }
        if q.contains("pair") || q.contains("stack") {
            if let pair = features.strongPairs.first {
                return "\(pair.a.capitalized) and \(pair.b.capitalized) tend to happen together (\(Int(pair.coOccurrenceRate * 100))%). Anchoring one to the other usually makes both stick."
            }
        }
        if q.contains("how am i") || q.contains("doing") {
            return "Last \(features.windowDays) days: \(Int(features.consistencyPct * 100))% consistency across all scheduled days."
        }
        let primary = try await coach(features: features)
        return primary.paragraph
    }

    // MARK: - Insight composition

    private func makeInsight(from f: SlipFeatures) -> CoachInsight {
        // Priority 1: slip window
        if let window = f.topSlipWindows.first, window.skipRate >= 0.5, window.attempts >= 4 {
            return slipWindowInsight(window: window)
        }
        // Priority 2: idle habit
        if let idleName = f.idleHabits.first {
            return idleHabitInsight(name: idleName, habitFeatures: f.perHabit.first { $0.name == idleName })
        }
        // Priority 3: stacking
        if let pair = f.strongPairs.first, pair.coOccurrenceRate >= 0.7 {
            return stackingInsight(pair: pair)
        }
        // Priority 4: low consistency → calm mode
        if f.consistencyPct < 0.4, f.totalScheduled >= 14 {
            return calmModeInsight(consistency: f.consistencyPct)
        }
        // Priority 5: weekday strength
        if let (bestIdx, bestRate) = bestWeekday(f), let (worstIdx, worstRate) = worstWeekday(f),
           bestRate - worstRate > 0.4 {
            return weekdayStrengthInsight(bestIdx: bestIdx, bestRate: bestRate,
                                          worstIdx: worstIdx, worstRate: worstRate)
        }
        // Default: steady
        return steadyInsight(consistency: f.consistencyPct)
    }

    private func slipWindowInsight(window: SlipWindow) -> CoachInsight {
        let day = SlipFeatureExtractor.weekdayName(window.weekday)
        let time = SlipFeatureExtractor.formatHour(window.bucketHour)
        let headline = "\(day)s around \(time) tend to slip"
        let pct = Int(window.skipRate * 100)
        let paragraph = "Looking at your last 30 days, \(pct)% of \(day) \(time.lowercased()) windows haven't landed. That's a clear pattern — not a character flaw."
        let suggestion = "Try shifting whichever habit normally lives in that window 2 hours earlier."
        for body in [paragraph, suggestion] {
            NotificationCopy.assertSafe(body, tone: .gentle)
        }
        return CoachInsight(headline: headline, paragraph: paragraph, suggestion: suggestion)
    }

    private func idleHabitInsight(name: String, habitFeatures: HabitFeatures?) -> CoachInsight {
        let days = habitFeatures?.daysSinceLastLog ?? 7
        let headline = "\(name.capitalized) has gone quiet"
        let paragraph: String
        let suggestion: String?
        if days >= 14 {
            paragraph = "\(name.capitalized) hasn't been logged in \(days) days. If it's not serving you right now, pausing it is a totally valid move."
            suggestion = "Open the habit's detail view and pause it for a while."
        } else {
            paragraph = "\(name.capitalized) hasn't been logged in \(days) days. Sometimes a habit takes a breather; sometimes it needs a tweak."
            suggestion = nil
        }
        NotificationCopy.assertSafe(paragraph, tone: .gentle)
        if let s = suggestion { NotificationCopy.assertSafe(s, tone: .gentle) }
        return CoachInsight(headline: headline, paragraph: paragraph,
                            suggestion: suggestion,
                            highlightedHabitID: habitFeatures?.id)
    }

    private func stackingInsight(pair: HabitPair) -> CoachInsight {
        let pct = Int(pair.coOccurrenceRate * 100)
        let headline = "\(pair.a.capitalized) + \(pair.b.capitalized) move together"
        let paragraph = "When you do \(pair.a.lowercased()), \(pair.b.lowercased()) follows \(pct)% of the time. That's already a strong stack — you can lean into it."
        let suggestion = "On days you skip one, anchor it to the other."
        NotificationCopy.assertSafe(paragraph, tone: .gentle)
        NotificationCopy.assertSafe(suggestion, tone: .gentle)
        return CoachInsight(headline: headline, paragraph: paragraph, suggestion: suggestion)
    }

    private func calmModeInsight(consistency: Double) -> CoachInsight {
        let pct = Int(consistency * 100)
        let headline = "Ease up signal"
        let paragraph = "Last 30 days landed around \(pct)% consistency. That's the calendar pointing at less, not pushing for more. Pause one habit if anything feels heavy."
        let suggestion = "Pick the least-essential habit and pause it for two weeks."
        NotificationCopy.assertSafe(paragraph, tone: .gentle)
        NotificationCopy.assertSafe(suggestion, tone: .gentle)
        return CoachInsight(headline: headline, paragraph: paragraph, suggestion: suggestion)
    }

    private func weekdayStrengthInsight(bestIdx: Int, bestRate: Double,
                                        worstIdx: Int, worstRate: Double) -> CoachInsight {
        let bestDay = SlipFeatureExtractor.weekdayName(bestIdx)
        let worstDay = SlipFeatureExtractor.weekdayName(worstIdx)
        let headline = "\(bestDay)s are your strongest"
        let paragraph = "\(bestDay)s land at \(Int(bestRate * 100))%; \(worstDay)s come in at \(Int(worstRate * 100))%. Knowing the asymmetry is half the trick."
        let suggestion = "Treat \(worstDay)s differently — fewer habits, earlier in the day, or a lighter version."
        NotificationCopy.assertSafe(paragraph, tone: .gentle)
        NotificationCopy.assertSafe(suggestion, tone: .gentle)
        return CoachInsight(headline: headline, paragraph: paragraph, suggestion: suggestion)
    }

    private func steadyInsight(consistency: Double) -> CoachInsight {
        let pct = Int(consistency * 100)
        let headline = "Steady rhythm"
        let paragraph = "Last 30 days are running about \(pct)%. No pattern jumping out as a problem — keep showing up the way you have been."
        NotificationCopy.assertSafe(paragraph, tone: .gentle)
        return CoachInsight(headline: headline, paragraph: paragraph, suggestion: nil)
    }

    /// Weekdays eligible for best/worst comparison: those that actually had scheduled
    /// attempts. A genuine 0%-completion weekday (attempts > 0, rate == 0) is exactly the
    /// WORST day the coach should surface, so it must stay eligible — only weekdays with
    /// no scheduled attempts are excluded.
    private func eligibleWeekdays(_ f: SlipFeatures) -> [(Int, Double)] {
        f.weekdayCompletion.enumerated().compactMap { idx, rate in
            let hasData: Bool
            if f.weekdayAttempts.indices.contains(idx) {
                hasData = f.weekdayAttempts[idx] > 0
            } else {
                hasData = rate > 0   // legacy callers without attempt counts: best we can do
            }
            return hasData ? (idx, rate) : nil
        }
    }

    private func bestWeekday(_ f: SlipFeatures) -> (Int, Double)? {
        eligibleWeekdays(f).max(by: { $0.1 < $1.1 })
    }

    private func worstWeekday(_ f: SlipFeatures) -> (Int, Double)? {
        eligibleWeekdays(f).min(by: { $0.1 < $1.1 })
    }
}
