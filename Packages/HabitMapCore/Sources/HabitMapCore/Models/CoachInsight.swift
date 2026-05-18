import Foundation

/// What the coach produces. Surfaced as a card at the top of the Insights screen.
public struct CoachInsight: Sendable, Equatable, Identifiable, Codable {
    public let id: UUID
    public let headline: String
    public let paragraph: String
    public let suggestion: String?
    public let highlightedHabitID: UUID?

    public init(id: UUID = UUID(),
                headline: String,
                paragraph: String,
                suggestion: String? = nil,
                highlightedHabitID: UUID? = nil) {
        self.id = id
        self.headline = headline
        self.paragraph = paragraph
        self.suggestion = suggestion
        self.highlightedHabitID = highlightedHabitID
    }

    public static let learning = CoachInsight(
        headline: "Still learning your patterns",
        paragraph: "Log a few days and the coach will start surfacing what works and what doesn't.",
        suggestion: nil,
        highlightedHabitID: nil
    )
}
