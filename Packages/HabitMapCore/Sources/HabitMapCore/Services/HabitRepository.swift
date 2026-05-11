import Foundation
import SwiftData

@MainActor
public final class HabitRepository: ObservableObject {
    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Pages

    @discardableResult
    public func createPage(name: String, emoji: String, accentHex: String) throws -> HabitPage {
        let nextSort = (try fetchPages().map(\.sortOrder).max() ?? -1) + 1
        let page = HabitPage(name: name.uppercased(), emoji: emoji, accentHex: accentHex, sortOrder: nextSort)
        context.insert(page)
        try context.save()
        return page
    }

    public func updatePage(_ page: HabitPage,
                           name: String? = nil,
                           emoji: String? = nil,
                           accentHex: String? = nil) throws {
        if let name { page.name = name.uppercased() }
        if let emoji { page.emoji = emoji }
        if let accentHex { page.accentHex = accentHex }
        try context.save()
    }

    public func reorderPages(_ ordered: [HabitPage]) throws {
        for (idx, page) in ordered.enumerated() { page.sortOrder = idx }
        try context.save()
    }

    public func archivePage(_ page: HabitPage) throws {
        page.isArchived = true
        try context.save()
    }

    public func deletePage(_ page: HabitPage, migrateTo target: HabitPage? = nil) throws {
        let habits = page.habits ?? []
        if !habits.isEmpty {
            guard let target else {
                throw HabitRepositoryError.pageHasHabitsRequireMigration(count: habits.count)
            }
            for habit in habits { habit.page = target }
        }
        context.delete(page)
        try context.save()
    }

    public func fetchPages(includeArchived: Bool = false) throws -> [HabitPage] {
        if includeArchived {
            let descriptor = FetchDescriptor<HabitPage>(sortBy: [SortDescriptor(\.sortOrder)])
            return try context.fetch(descriptor)
        } else {
            let descriptor = FetchDescriptor<HabitPage>(
                predicate: #Predicate { !$0.isArchived },
                sortBy: [SortDescriptor(\.sortOrder)]
            )
            return try context.fetch(descriptor)
        }
    }

    // MARK: - Habits

    @discardableResult
    public func createHabit(name: String,
                            emoji: String,
                            accentHex: String,
                            type: HabitType,
                            targetReps: Int,
                            weekdayMask: Int8,
                            restDayMask: Int8 = 0,
                            reminderTime: Date? = nil,
                            on page: HabitPage) throws -> Habit {
        let nextSort = ((page.habits ?? []).map(\.sortOrder).max() ?? -1) + 1
        let habit = Habit(name: name.uppercased(),
                          emoji: emoji,
                          accentHex: accentHex,
                          type: type,
                          targetReps: targetReps,
                          weekdayMask: weekdayMask,
                          restDayMask: restDayMask,
                          sortOrder: nextSort,
                          page: page)
        habit.reminderTime = reminderTime
        context.insert(habit)
        try context.save()
        return habit
    }

    public func updateHabit(_ habit: Habit,
                            name: String? = nil,
                            emoji: String? = nil,
                            accentHex: String? = nil,
                            targetReps: Int? = nil,
                            weekdayMask: Int8? = nil,
                            restDayMask: Int8? = nil,
                            reminderTime: Date?? = nil,
                            page: HabitPage? = nil) throws {
        if let name { habit.name = name.uppercased() }
        if let emoji { habit.emoji = emoji }
        if let accentHex { habit.accentHex = accentHex }
        if let targetReps { habit.targetReps = targetReps }
        if let weekdayMask { habit.weekdayMask = weekdayMask }
        if let restDayMask { habit.restDayMask = restDayMask }
        if let reminderTime { habit.reminderTime = reminderTime }
        if let page { habit.page = page }
        try context.save()
    }

    public func archiveHabit(_ habit: Habit) throws {
        habit.isArchived = true
        try context.save()
    }

    public func deleteHabit(_ habit: Habit) throws {
        context.delete(habit)
        try context.save()
    }

    public func reorderHabits(_ ordered: [Habit]) throws {
        for (idx, habit) in ordered.enumerated() { habit.sortOrder = idx }
        try context.save()
    }
}

public enum HabitRepositoryError: LocalizedError {
    case pageHasHabitsRequireMigration(count: Int)

    public var errorDescription: String? {
        switch self {
        case .pageHasHabitsRequireMigration(let n):
            return "Cannot delete page with \(n) habit\(n == 1 ? "" : "s"). Choose a destination page first."
        }
    }
}
