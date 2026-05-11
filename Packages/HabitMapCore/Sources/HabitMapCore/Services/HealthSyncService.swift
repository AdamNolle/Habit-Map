import Foundation
import SwiftData

@MainActor
public final class HealthSyncService: ObservableObject {
    public let provider: HealthKitProviding
    public let repository: HabitRepository
    @Published public private(set) var lastSyncedAt: Date?

    public init(provider: HealthKitProviding, repository: HabitRepository) {
        self.provider = provider
        self.repository = repository
    }

    /// Walk every active `.autoHealth` habit, query its metric for today, upsert a completion.
    public func syncToday() async {
        let habits: [Habit]
        do {
            let pages = try repository.fetchPages(includeArchived: false)
            habits = pages.flatMap { ($0.habits ?? []).filter { !$0.isArchived && !$0.isPaused && $0.type == .autoHealth } }
        } catch {
            return
        }
        for habit in habits {
            await syncHabit(habit)
        }
        lastSyncedAt = Date()
    }

    public func syncHabit(_ habit: Habit) async {
        guard let metric = habit.healthMetric else { return }
        do {
            let value = try await provider.todayTotal(for: metric, on: Date())
            upsertCompletion(habit: habit, value: value)
        } catch {
            // Silent failure: existing completion (if any) is left intact.
        }
    }

    private func upsertCompletion(habit: Habit, value: Double) {
        let today = Date.startOfToday()
        let reps = Int(value)
        if let existing = habit.completion(on: today) {
            existing.reps = reps
            existing.loggedAt = Date()
            existing.sourceRaw = CompletionSource.health.rawValue
        } else {
            let completion = HabitCompletion(date: today, reps: reps, source: .health, habit: habit)
            repository.context.insert(completion)
        }
        try? repository.context.save()
    }
}
