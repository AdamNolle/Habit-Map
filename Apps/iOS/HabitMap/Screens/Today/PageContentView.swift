import SwiftUI
import HabitMapCore

struct PageContentView: View {
    let page: HabitPage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                HeaderView(page: page)
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
    }
}
