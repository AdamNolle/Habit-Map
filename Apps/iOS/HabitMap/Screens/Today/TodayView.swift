import SwiftUI
import SwiftData
import HabitMapCore

struct TodayView: View {
    @Query(sort: \HabitPage.sortOrder) private var pages: [HabitPage]
    @EnvironmentObject private var repo: HabitRepository
    @EnvironmentObject private var haptics: Haptics
    @State private var selectedPageID: UUID?
    @State private var wizardPage: HabitPage?
    @State private var showAddPage = false

    private var activePages: [HabitPage] { pages.filter { !$0.isArchived } }

    var body: some View {
        ZStack(alignment: .bottom) {
            DesignTokens.Surface.bg.ignoresSafeArea()

            if activePages.isEmpty {
                VStack(spacing: 0) {
                    Spacer()
                    GlassCard(cornerRadius: 18, padding: 24) {
                        VStack(spacing: 12) {
                            Image(systemName: "map")
                                .font(.system(size: 40))
                                .foregroundColor(DesignTokens.Accent.classicGreen)
                            Text("Start your map")
                                .font(.custom(FontFamily.serif, size: 22))
                                .italic()
                                .foregroundColor(DesignTokens.Surface.fg())
                            Text("Create your first habit page to begin tracking.")
                                .font(.custom(FontFamily.sans, size: 14))
                                .multilineTextAlignment(.center)
                                .foregroundColor(DesignTokens.Surface.mutedText)
                            AppButton("Create first page", style: .filled, accent: DesignTokens.Accent.classicGreen) {
                                haptics.sheetPresent()
                                showAddPage = true
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 32)
                    Spacer()
                }
            } else {
                TabView(selection: $selectedPageID) {
                    ForEach(activePages) { page in
                        PageContentView(page: page)
                            .tag(page.id as UUID?)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onAppear {
                    // First appearance only (guarded by nil) — not a per-render fetch.
                    if selectedPageID == nil {
                        let defaultID = (try? repo.userSettings())?.defaultPageId
                        if let defaultID, activePages.contains(where: { $0.id == defaultID }) {
                            selectedPageID = defaultID
                        } else {
                            selectedPageID = activePages.first?.id
                        }
                    }
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
        .sheet(isPresented: $showAddPage) {
            AddPageSheet()
                .environmentObject(repo)
                .environmentObject(haptics)
        }
        .onReceive(NotificationCenter.default.publisher(for: .habitMapNotificationTapped)) { note in
            // Route a per-habit notification tap to the page that habit lives on.
            guard let habitID = note.userInfo?["habitID"] as? UUID,
                  let pageID = HabitNotificationID.pageID(forHabit: habitID, in: activePages) else { return }
            selectedPageID = pageID
        }
    }
}

extension HabitPage: Identifiable {}
