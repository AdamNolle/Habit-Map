import Foundation

/// Maps a habit name (matched case-insensitively against a curated set) to a SF
/// Symbol identifier. Used by HabitRow's IconTile + the wizard preview.
public enum HabitIcon {
    /// Curated map. Lookup tries the full name first, then individual tokens.
    public static let dictionary: [String: String] = [
        "drink water":     "drop.fill",
        "water":           "drop.fill",
        "hydration":       "drop.fill",
        "run":             "figure.run",
        "running":         "figure.run",
        "walk":            "figure.walk",
        "steps":           "shoeprints.fill",
        "vitamins":        "pills.fill",
        "stand hours":     "figure.stand",
        "stand":           "figure.stand",
        "meditate":        "sparkle",
        "mindful":         "sparkle",
        "sleep":           "moon.fill",
        "read":            "book.fill",
        "journal":         "pencil.and.scribble",
        "stretch":         "figure.cooldown",
        "yoga":            "figure.mind.and.body",
        "workout":         "dumbbell.fill",
        "lift":            "dumbbell.fill",
        "no doomscroll":   "iphone.slash",
        "no soda":         "cup.and.saucer.fill",
        "deep work":       "target",
        "inbox zero":      "envelope.fill",
        "email":           "envelope.fill",
        "calls":           "phone.fill",
        "code":            "chevron.left.forwardslash.chevron.right",
        "music":           "music.note",
        "draw":            "paintbrush.fill",
        "guitar":          "guitars.fill",
        "garden":          "leaf.fill",
        "cook":            "fork.knife",
        "dishes":          "dishwasher.fill",
        "laundry":         "washer.fill",
        "tidy":            "tray.fill",
        "calories":        "flame.fill",
        "workouts":        "dumbbell.fill",
        "distance":        "figure.run.circle",
        "active energy":   "flame.fill",
        "heart rate":      "heart.fill"
    ]

    public static let fallbackSymbol = "circle.dotted"

    /// Resolves a habit name to a SF Symbol. Tries full lookup, then token splits.
    public static func symbol(for habitName: String) -> String {
        let normalized = habitName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = dictionary[normalized] { return direct }
        for token in normalized.split(separator: " ") {
            if let match = dictionary[String(token)] { return match }
        }
        return fallbackSymbol
    }
}
