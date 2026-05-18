import Foundation

public extension String {
    /// Returns the string in Title Case (each whitespace-delimited word capitalized).
    var titleCased: String {
        let lower = lowercased()
        var result = ""
        var capitalizeNext = true
        for ch in lower {
            if ch.isWhitespace {
                capitalizeNext = true
                result.append(ch)
            } else if capitalizeNext {
                result.append(ch.uppercased())
                capitalizeNext = false
            } else {
                result.append(ch)
            }
        }
        return result
    }
}

public enum HabitDateLabel {
    /// "Mon, May 18" formatted for the Today header eyebrow.
    public static func today(now: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: now)
    }
}
