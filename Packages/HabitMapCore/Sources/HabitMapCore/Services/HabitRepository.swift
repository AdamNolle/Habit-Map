import Foundation
import SwiftData

public enum HabitChange: Sendable {
    case created, updated, archived, deleted
}

@MainActor
public final class HabitRepository: ObservableObject {
    public let context: ModelContext
    public var onHabitChanged: ((Habit, HabitChange) -> Void)?

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
        onHabitChanged?(habit, .created)
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
        onHabitChanged?(habit, .updated)
    }

    public func archiveHabit(_ habit: Habit) throws {
        habit.isArchived = true
        try context.save()
        onHabitChanged?(habit, .archived)
    }

    public func deleteHabit(_ habit: Habit) throws {
        let cached = habit
        context.delete(habit)
        try context.save()
        onHabitChanged?(cached, .deleted)
    }

    public func reorderHabits(_ ordered: [Habit]) throws {
        for (idx, habit) in ordered.enumerated() { habit.sortOrder = idx }
        try context.save()
    }

    // MARK: - Completions

    /// Writes (or clears) the note on `habit`'s completion for `date`, creating the
    /// completion if one doesn't exist yet, then persists. If the save throws, the
    /// in-memory change is rolled back so callers never show a note that didn't save.
    public func setNote(_ note: String?, for habit: Habit, on date: Date) throws {
        let trimmed = (note?.isEmpty == true) ? nil : note
        if let existing = habit.completion(on: date) {
            let prior = existing.note
            existing.note = trimmed
            do {
                try context.save()
            } catch {
                existing.note = prior
                throw error
            }
        } else {
            let completion = HabitCompletion(date: date, reps: 0, note: trimmed, habit: habit)
            context.insert(completion)
            do {
                try context.save()
            } catch {
                context.delete(completion)
                throw error
            }
        }
    }

    // MARK: - Settings

    public func userSettings() throws -> UserSettings {
        try UserSettings.fetchOrCreate(in: context)
    }

    // MARK: - Reset

    public enum DeleteScope: Sendable {
        case archivedOnly
        case everything
    }

    public func deleteAll(scope: DeleteScope) throws {
        switch scope {
        case .archivedOnly:
            for page in try fetchPages(includeArchived: true) where page.isArchived {
                for habit in (page.habits ?? []) {
                    context.delete(habit)
                }
                context.delete(page)
            }
        case .everything:
            let pages = try fetchPages(includeArchived: true)
            for page in pages {
                for habit in (page.habits ?? []) {
                    context.delete(habit)
                }
                context.delete(page)
            }
            let allCompletions = try context.fetch(FetchDescriptor<HabitCompletion>())
            for c in allCompletions { context.delete(c) }
            let allSettings = try context.fetch(FetchDescriptor<UserSettings>())
            for s in allSettings { context.delete(s) }
        }
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
