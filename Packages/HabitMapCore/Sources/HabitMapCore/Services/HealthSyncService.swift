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
        // Gate BEFORE querying: HealthKit read queries silently return 0/empty when
        // access is denied/undetermined (they do NOT throw), so without this guard an
        // unauthorized sync would clobber real completions with reps=0.
        guard await provider.authState(for: [metric]) == .authorized else { return }
        do {
            let value = try await provider.todayTotal(for: metric, on: Date())
            upsertCompletion(habit: habit, value: value)
        } catch {
            // Silent failure: existing completion (if any) is left intact.
        }
    }

    /// Non-destructive upsert: never lowers a value and never overwrites a
    /// non-`.health` completion, so manual/watch/siri provenance and streaks survive
    /// a transient empty read or a revoked-permission read.
    private func upsertCompletion(habit: Habit, value: Double) {
        let today = Date.startOfToday()
        let newReps = Int(value)
        if let existing = habit.completion(on: today) {
            // Preserve provenance: only health-sourced completions may be touched.
            guard existing.source == .health else { return }
            // Monotonic: only raise reps; never lower on a transient smaller read.
            guard newReps > existing.reps else { return }
            existing.reps = newReps
            existing.loggedAt = Date()
        } else {
            // Nothing to record for a zero read.
            guard newReps > 0 else { return }
            let completion = HabitCompletion(date: today, reps: newReps, source: .health, habit: habit)
            repository.context.insert(completion)
        }
        try? repository.context.save()
    }
}
