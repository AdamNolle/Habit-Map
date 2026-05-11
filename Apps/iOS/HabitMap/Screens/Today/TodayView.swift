import SwiftUI
import SwiftData
import HabitMapCore

struct TodayView: View {
    @Query(sort: \HabitPage.sortOrder) private var pages: [HabitPage]
    @EnvironmentObject private var repo: HabitRepository
    @State private var selectedPageID: UUID?
    @State private var wizardPage: HabitPage?

    var body: some View {
        ZStack(alignment: .bottom) {
            DesignTokens.Surface.bg.ignoresSafeArea()

            if pages.filter({ !$0.isArchived }).isEmpty {
                ProgressView()
                    .tint(DesignTokens.Surface.mutedText)
            } else {
                TabView(selection: $selectedPageID) {
                    ForEach(pages.filter { !$0.isArchived }) { page in
                        PageContentView(page: page)
                            .tag(page.id as UUID?)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onAppear {
                    if selectedPageID == nil { selectedPageID = pages.filter({ !$0.isArchived }).first?.id }
                }
                .onChange(of: pages) { _, newPages in
                    let active = newPages.filter { !$0.isArchived }
                    if !active.contains(where: { $0.id == selectedPageID }) {
                        selectedPageID = active.first?.id
                    }
                }
            }

            VStack(spacing: 8) {
                let active = pages.filter { !$0.isArchived }
                if !active.isEmpty {
                    PageDots(count: active.count,
                             activeIndex: active.firstIndex { $0.id == selectedPageID } ?? 0,
                             activeColor: active.first { $0.id == selectedPageID }?.accentColor
                                              ?? DesignTokens.Surface.mutedText)
                        .padding(.bottom, 8)
                }
            }
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomTrailing) {
            if let id = selectedPageID,
               let page = pages.first(where: { $0.id == id }) {
                FAB(accent: page.accentColor) { wizardPage = page }
                    .padding(.trailing, DesignTokens.Spacing.lg)
                    .padding(.bottom, 16)
                    .accessibilityLabel("Add habit to \(page.name)")
            }
        }
        .sheet(item: $wizardPage) { page in
            AddHabitWizardView(page: page).environmentObject(repo)
        }
        .preferredColorScheme(.dark)
    }
}

extension HabitPage: Identifiable {}
