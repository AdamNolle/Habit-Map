import SwiftUI
import SwiftData
import HabitMapCore

struct TodayView: View {
    @Query(sort: \HabitPage.sortOrder) private var pages: [HabitPage]
    @EnvironmentObject private var repo: HabitRepository
    @EnvironmentObject private var haptics: Haptics
    @State private var selectedPageID: UUID?
    @State private var wizardPage: HabitPage?

    private var activePages: [HabitPage] { pages.filter { !$0.isArchived } }

    var body: some View {
        ZStack(alignment: .bottom) {
            DesignTokens.Surface.bg.ignoresSafeArea()

            if activePages.isEmpty {
                ProgressView()
                    .tint(DesignTokens.Surface.mutedText)
            } else {
                TabView(selection: $selectedPageID) {
                    ForEach(activePages) { page in
                        PageContentView(page: page)
                            .tag(page.id as UUID?)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onAppear {
                    if selectedPageID == nil { selectedPageID = activePages.first?.id }
                }
                .onChange(of: pages) { _, newPages in
                    let active = newPages.filter { !$0.isArchived }
                    if !active.contains(where: { $0.id == selectedPageID }) {
                        selectedPageID = active.first?.id
                    }
                }
                .onChange(of: selectedPageID) { _, _ in
                    haptics.pageSwipe()
                }
            }

            // Page dots
            if !activePages.isEmpty {
                PageDots(
                    count: activePages.count,
                    activeIndex: activePages.firstIndex { $0.id == selectedPageID } ?? 0,
                    activeColor: activePages.first { $0.id == selectedPageID }?.accentColor
                        ?? DesignTokens.Surface.mutedText
                )
                .padding(.bottom, 8)
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let id = selectedPageID,
               let page = activePages.first(where: { $0.id == id }) {
                FAB(accent: page.accentColor) { wizardPage = page }
                    .padding(.trailing, DesignTokens.Spacing.xl)
                    .padding(.bottom, 16)
                    .accessibilityLabel("Add habit to \(page.name)")
            }
        }
        .sheet(item: $wizardPage) { page in
            AddHabitWizardView(page: page)
                .environmentObject(repo)
                .environmentObject(haptics)
        }
    }
}

extension HabitPage: Identifiable {}
