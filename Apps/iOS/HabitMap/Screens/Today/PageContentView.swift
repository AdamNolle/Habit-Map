import SwiftUI
import SwiftData
import HabitMapCore

struct PageContentView: View {
    let page: HabitPage
    @Query(filter: #Predicate<HabitPage> { !$0.isArchived }) private var allPages: [HabitPage]
    @State private var showPagesManager = false
    @EnvironmentObject private var repo: HabitRepository
    @EnvironmentObject private var haptics: Haptics
    private let stats = StatsService()

    var body: some View {
        let habits = (page.habits ?? [])
            .filter { !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TodayHeader(
                    page: page,
                    doneCount: habits.filter { $0.progressFraction(on: Date()) >= 1.0 }.count,
                    total: habits.count,
                    onOpenPages: { showPagesManager = true }
                )
                .padding(.bottom, 14)

                if showCalmBanner {
                    CalmModeBanner(
                        onManage: { showPagesManager = true },
                        onDismiss: {
                            UserDefaults.standard.set(true, forKey: Self.dismissedKey(for: Date()))
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                }

                // Habits in glass container
                VStack(spacing: 0) {
                    ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                        if index > 0 {
                            Rectangle()
                                .fill(DesignTokens.Surface.hairline())
                                .frame(height: 1)
                                .padding(.leading, 18)
                        }
                        HabitRow(habit: habit, index: index)
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                }
                .overlay(alignment: .top) {
                    LinearGradient(colors: [.white.opacity(0.06), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 1)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                .padding(.horizontal, 20)

                MasterHeatmapCard(page: page, days: 28)
                    .padding(.horizontal, 20)
                    .padding(.top, 18)

                Spacer(minLength: 120)
            }
            .padding(.bottom, DesignTokens.Spacing.lg)
        }
        .background(DesignTokens.Surface.bg)
        .sheet(isPresented: $showPagesManager) {
            PagesManagerView()
                .environmentObject(repo)
                .environmentObject(haptics)
        }
    }

    private var showCalmBanner: Bool {
        guard !UserDefaults.standard.bool(forKey: Self.dismissedKey(for: Date())) else { return false }
        let activeHabits = allPages.flatMap { ($0.habits ?? []).filter { !$0.isArchived && !$0.isPaused } }
        guard !activeHabits.isEmpty else { return false }
        let threshold = (try? repo.userSettings())?.calmModeThreshold ?? 0.55
        return stats.consistency(habits: activeHabits, window: 30) < threshold
    }

    private static func dismissedKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "habitmap.calmMode.dismissed.\(f.string(from: date))"
    }
}
