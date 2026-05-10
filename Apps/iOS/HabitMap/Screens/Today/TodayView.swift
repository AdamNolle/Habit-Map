import SwiftUI
import SwiftData
import HabitMapCore

struct TodayView: View {
    @Query(sort: \HabitPage.sortOrder) private var pages: [HabitPage]
    @State private var selectedPageID: UUID?

    var body: some View {
        ZStack(alignment: .bottom) {
            DesignTokens.Surface.bg.ignoresSafeArea()

            if pages.isEmpty {
                ProgressView()
                    .tint(DesignTokens.Surface.mutedText)
            } else {
                TabView(selection: $selectedPageID) {
                    ForEach(pages) { page in
                        PageContentView(page: page)
                            .tag(page.id as UUID?)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onAppear {
                    if selectedPageID == nil { selectedPageID = pages.first?.id }
                }
            }

            VStack(spacing: 8) {
                if !pages.isEmpty {
                    PageDots(count: pages.count,
                             activeIndex: pages.firstIndex { $0.id == selectedPageID } ?? 0,
                             activeColor: pages.first { $0.id == selectedPageID }?.accentColor
                                              ?? DesignTokens.Surface.mutedText)
                }
                TabBar(active: .today)
            }
        }
        .preferredColorScheme(.dark)
    }
}
