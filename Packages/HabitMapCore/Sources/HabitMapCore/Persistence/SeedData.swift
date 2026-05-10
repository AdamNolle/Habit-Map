import Foundation
import SwiftData

public enum SeedData {
    @MainActor
    public static func installDemo(into context: ModelContext) throws {
        let page = HabitPage(name: "HEALTH",
                             emoji: "🩺",
                             accentHex: "#2BFF5F",
                             sortOrder: 0)
        context.insert(page)

        let water = Habit(name: "DRINK WATER",
                          emoji: "💧",
                          accentHex: "#3DA4FF",
                          type: .manualMultiple,
                          targetReps: 4,
                          sortOrder: 0,
                          page: page)
        context.insert(water)

        // Seed 30 days of history so the mini-heatmap has content.
        let cal = Calendar.current
        for offset in 1...30 {
            guard let date = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let reps = Int.random(in: 0...4)
            if reps > 0 {
                context.insert(HabitCompletion(date: date, reps: reps, habit: water))
            }
        }
        try context.save()
    }
}
