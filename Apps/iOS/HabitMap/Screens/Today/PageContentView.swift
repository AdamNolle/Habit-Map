import SwiftUI
import SwiftData
import HabitMapCore

struct PageContentView: View {
    let page: HabitPage
    @Query(filter: #Predicate<HabitPage> { !$0.isArchived }) private var allPages: [HabitPage]
    @State private var settings: UserSettings?
    @State private var calmDismissedKey: String = Self.todayKey()
    @State private var showPagesManager = false
    @EnvironmentObject private var repo: HabitRepository
    private let stats = StatsService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                HeaderView(page: page)

                if showCalmBanner {
                    CalmModeBanner(
                        onManage: { showPagesManager = true },
                        onDismiss: {
                            UserDefaults.standard.set(true, forKey: Self.dismissedKey(for: Date()))
                            calmDismissedKey = Self.todayKey()  // trigger recompute
                        }
                    )
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                }

                MasterHeatmapCard(page: page)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                VStack(spacing: DesignTokens.Spacing.md) {
                    ForEach((page.habits ?? []).filter { !$0.isArchived }.sorted(by: { $0.sortOrder < $1.sortOrder })) { habit in
                        HabitRow(habit: habit)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                Spacer(minLength: 100)
            }
            .padding(.bottom, DesignTokens.Spacing.lg)
        }
        .background(DesignTokens.Surface.bg)
        .task {
            settings = try? repo.userSettings()
        }
        .sheet(isPresented: $showPagesManager) {
            PagesManagerView().environmentObject(repo)
        }
    }

    private var showCalmBanner: Bool {
        guard let settings else { return false }
        if UserDefaults.standard.bool(forKey: Self.dismissedKey(for: Date())) { return false }
        let activeHabits = allPages.flatMap { ($0.habits ?? []).filter { !$0.isArchived && !$0.isPaused } }
        guard !activeHabits.isEmpty else { return false }
        let consistency = stats.consistency(habits: activeHabits, window: 30)
        return consistency < settings.calmModeThreshold
    }

    private static func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private static func dismissedKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "habitmap.calmMode.dismissed.\(f.string(from: date))"
    }
}
