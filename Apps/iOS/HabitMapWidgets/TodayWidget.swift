import WidgetKit
import SwiftUI
import SwiftData
import HabitMapCore

struct TodayEntry: TimelineEntry, Sendable {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: Date(), snapshot: Self.resolveSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = TodayEntry(date: Date(), snapshot: Self.resolveSnapshot())
        // Refresh roughly hourly; completion changes also nudge WidgetCenter from the app.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
            ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    /// WidgetKit invokes provider callbacks on the main actor, where SwiftData's
    /// `mainContext` is safe to read.
    private static func resolveSnapshot() -> WidgetSnapshot {
        MainActor.assumeIsolated { loadSnapshot() }
    }

    @MainActor
    private static func loadSnapshot() -> WidgetSnapshot {
        guard let container = try? PersistenceController.makeContainer(
            enableCloudKit: false,
            appGroupID: PersistenceController.appGroupID
        ) else { return .placeholder }

        let descriptor = FetchDescriptor<HabitPage>(predicate: #Predicate { !$0.isArchived })
        let pages = (try? container.mainContext.fetch(descriptor)) ?? []
        let habits = pages.flatMap { $0.habits ?? [] }
        let accent = pages.first?.accentHex ?? "#2BFF5F"
        return WidgetStatsProvider.snapshot(habits: habits, accentHex: accent)
    }
}

struct TodayWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        HabitWidgetView(snapshot: entry.snapshot, isCompact: family == .systemSmall)
            .containerBackground(for: .widget) { DesignTokens.Surface.bg }
    }
}

struct TodayWidget: Widget {
    let kind = "HabitMapTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Your 30-day consistency, current streak, and today's progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    TodayWidget()
} timeline: {
    TodayEntry(date: .now, snapshot: .placeholder)
}
