import Foundation

public enum InsightKind: String, Sendable, CaseIterable {
    case win, risk, suggest
}

public struct Insight: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let kind: InsightKind
    public let title: String
    public let body: String
    public let primaryHabitID: UUID?
    public let primaryHabitName: String?
    public let primaryAccentHex: String?

    public init(id: UUID = UUID(),
                kind: InsightKind,
                title: String,
                body: String,
                primaryHabitID: UUID? = nil,
                primaryHabitName: String? = nil,
                primaryAccentHex: String? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.primaryHabitID = primaryHabitID
        self.primaryHabitName = primaryHabitName
        self.primaryAccentHex = primaryAccentHex
    }
}
