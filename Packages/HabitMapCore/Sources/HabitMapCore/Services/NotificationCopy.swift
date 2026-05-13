import Foundation

public enum NotificationCopy {
    /// Phrases that should NEVER appear in gentle-tone notification body text.
    /// Matched case-insensitively.
    public static let bannedInGentle: [String] = [
        "broken", "failed", "missed", "you didn't", "streak lost", "don't"
    ]

    // MARK: - Daily reminder

    public static func dailyReminderTitle(tone: NotificationTone) -> String {
        switch tone {
        case .gentle: return "Habit Map"
        case .direct: return "REMINDERS"
        }
    }

    public static func dailyReminderBody(tone: NotificationTone, pendingCount: Int) -> String {
        let body: String
        switch tone {
        case .gentle:
            if pendingCount == 0 {
                body = "Today is open — log when you're ready."
            } else {
                body = "\(pendingCount) habit\(pendingCount == 1 ? "" : "s") waiting whenever you're ready."
            }
        case .direct:
            body = "\(pendingCount) habit\(pendingCount == 1 ? "" : "s") remaining today."
        }
        assertSafe(body, tone: tone)
        return body
    }

    // MARK: - Weekly reflection

    public static func weeklyReflectionTitle(tone: NotificationTone) -> String {
        switch tone {
        case .gentle: return "Weekly Reflection"
        case .direct: return "WEEKLY REVIEW"
        }
    }

    public static func weeklyReflectionBody(tone: NotificationTone) -> String {
        let body: String
        switch tone {
        case .gentle:
            body = "Take a moment to look back. What worked this week?"
        case .direct:
            body = "Week summary ready. Review now."
        }
        assertSafe(body, tone: tone)
        return body
    }

    // MARK: - Per-habit reminder

    public static func habitReminderTitle(tone: NotificationTone, habitName: String) -> String {
        switch tone {
        case .gentle: return habitName.capitalized
        case .direct: return habitName.uppercased()
        }
    }

    public static func habitReminderBody(tone: NotificationTone, habitName: String) -> String {
        let body: String
        switch tone {
        case .gentle:
            body = "A gentle nudge for \(habitName.lowercased()) — log when it fits."
        case .direct:
            body = "Time for \(habitName.uppercased())."
        }
        assertSafe(body, tone: tone)
        return body
    }

    // MARK: - Safety

    /// In DEBUG, crashes if gentle-tone copy contains a banned phrase. In release, logs.
    public static func assertSafe(_ body: String, tone: NotificationTone) {
        guard tone == .gentle else { return }
        let lower = body.lowercased()
        for phrase in bannedInGentle {
            if lower.contains(phrase.lowercased()) {
                #if DEBUG
                assertionFailure("Banned phrase '\(phrase)' in gentle copy: \(body)")
                #else
                print("WARN: banned phrase '\(phrase)' in gentle copy: \(body)")
                #endif
                return
            }
        }
    }
}
