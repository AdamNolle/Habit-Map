import Foundation
import SwiftData
import SwiftUI

@Model
public final class HabitPage {
    public var id: UUID = UUID()
    public var name: String = ""
    public var emoji: String = ""
    public var accentHex: String = "#2BFF5F"
    public var sortOrder: Int = 0
    public var isArchived: Bool = false
    public var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Habit.page)
    public var habits: [Habit]? = []

    public init(id: UUID = UUID(),
                name: String,
                emoji: String,
                accentHex: String,
                sortOrder: Int,
                isArchived: Bool = false,
                createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.accentHex = accentHex
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.createdAt = createdAt
    }

    public var accentColor: Color { Color(hex: accentHex) }
}
