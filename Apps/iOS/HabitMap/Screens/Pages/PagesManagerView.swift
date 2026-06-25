import SwiftUI
import SwiftData
import HabitMapCore

struct PagesManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repo: HabitRepository
    @EnvironmentObject private var haptics: Haptics
    @Query(filter: #Predicate<HabitPage> { !$0.isArchived },
           sort: \HabitPage.sortOrder) private var activePages: [HabitPage]
    @Query(filter: #Predicate<HabitPage> { $0.isArchived },
           sort: \HabitPage.sortOrder) private var archivedPages: [HabitPage]

    @State private var showAddSheet = false
    @State private var editingPage: HabitPage?
    @State private var deletingPage: HabitPage?

    var body: some View {
        NavigationStack {
            List {
                Section("Active") {
                    ForEach(activePages) { page in
                        pageRow(page)
                    }
                    .onMove(perform: move)
                    .onDelete(perform: requestDelete)
                    Button {
                        showAddSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(DesignTokens.Accent.classicGreen)
                            Text("New page")
                                .font(.custom(FontFamily.sans, size: 15))
                                .fontWeight(.medium)
                                .foregroundColor(DesignTokens.Accent.classicGreen)
                        }
                    }
                    .accessibilityLabel("Add page")
                }
                if !archivedPages.isEmpty {
                    Section("Archived") {
                        ForEach(archivedPages) { page in
                            pageRow(page).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(DesignTokens.Surface.bg)
            .navigationTitle("Pages")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
            .sheet(isPresented: $showAddSheet) {
                AddPageSheet()
                    .environmentObject(repo)
                    .environmentObject(haptics)
            }
            .sheet(item: $editingPage) { page in
                EditPageSheet(page: page)
                    .environmentObject(repo)
                    .environmentObject(haptics)
            }
            .alert("Delete page?",
                   isPresented: Binding(get: { deletingPage != nil },
                                        set: { if !$0 { deletingPage = nil } }),
                   presenting: deletingPage) { page in
                let habits = (page.habits ?? []).count
                let other = activePages.first { $0.id != page.id }
                if habits > 0 {
                    if let other {
                        Button("Delete & migrate", role: .destructive) {
                            try? repo.deletePage(page, migrateTo: other)
                            deletingPage = nil
                        }
                    }
                    Button("Archive instead") {
                        try? repo.archivePage(page)
                        deletingPage = nil
                    }
                    Button("Cancel", role: .cancel) { deletingPage = nil }
                } else {
                    Button("Delete", role: .destructive) {
                        try? repo.deletePage(page)
                        deletingPage = nil
                    }
                    Button("Cancel", role: .cancel) { deletingPage = nil }
                }
            } message: { page in
                let n = (page.habits ?? []).count
                let hasOther = activePages.contains { $0.id != page.id }
                if n > 0 {
                    if hasOther {
                        Text("This page has \(n) habit\(n == 1 ? "" : "s"). Migrate them to another page or archive this page instead.")
                    } else {
                        Text("This page has \(n) habit\(n == 1 ? "" : "s") and is your only active page. Archive it to keep them.")
                    }
                } else {
                    Text("This action is permanent.")
                }
            }
        }
    }

    private func pageRow(_ page: HabitPage) -> some View {
        HStack {
            Text(page.emoji).font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(page.name.titleCased)
                    .font(.custom(FontFamily.sans, size: 15))
                    .fontWeight(.semibold)
                    .foregroundColor(page.accentColor)
                    .accessibilityLabel(page.name)
                let habitCount = (page.habits ?? []).count
                Text("\(habitCount) habit\(habitCount == 1 ? "" : "s")")
                    .font(.custom(FontFamily.sans, size: 12))
                    .foregroundColor(DesignTokens.Surface.mutedText)
            }
            Spacer()
            Circle()
                .fill(page.accentColor)
                .frame(width: 10, height: 10)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { editingPage = page }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = activePages
        reordered.move(fromOffsets: source, toOffset: destination)
        try? repo.reorderPages(reordered)
    }

    private func requestDelete(at offsets: IndexSet) {
        for idx in offsets { deletingPage = activePages[idx] }
    }
}
