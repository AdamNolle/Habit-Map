import SwiftUI
import SwiftData
import HabitMapCore

struct SettingsView: View {
    @EnvironmentObject private var repo: HabitRepository
    @EnvironmentObject private var notifications: NotificationCoordinator
    @EnvironmentObject private var haptics: Haptics
    @Query(filter: #Predicate<HabitPage> { !$0.isArchived },
           sort: \HabitPage.sortOrder) private var pages: [HabitPage]
    @State private var settings: UserSettings?
    @State private var showPages = false
    @State private var resetStep: ResetStep = .idle
    @State private var resetScope: ResetScope = .everything
    @State private var resetConfirmation: String = ""
    private let stats = StatsService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow("Habit Map · v0.1")
                    Display("Settings", size: 44, italic: true)
                }
                .padding(.top, 4)

                if let settings {
                    settingsSection("Pages") { pagesContent(settings: settings) }
                    settingsSection("Appearance") { appearanceContent(settings: settings) }
                    settingsSection("Behavior") { behaviorContent(settings: settings) }
                    settingsSection("Danger zone") { dangerContent }
                } else {
                    ProgressView()
                        .tint(DesignTokens.Surface.mutedText)
                        .frame(maxWidth: .infinity, minHeight: 200)
                }

                AboutSection().padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .background(DesignTokens.Surface.bg)
        .task { settings = try? repo.userSettings() }
        .sheet(isPresented: $showPages) { PagesManagerView().environmentObject(repo) }
        .alert("Reset what?",
               isPresented: Binding(get: { resetStep == .scope }, set: { if !$0 { resetStep = .idle } })) {
            Button("Everything", role: .destructive) { resetScope = .everything; resetStep = .confirm }
            Button("Archived pages only") { resetScope = .archived; resetStep = .confirm }
            Button("Cancel", role: .cancel) { resetStep = .idle }
        }
        .alert("Type RESET to confirm",
               isPresented: Binding(get: { resetStep == .confirm }, set: { if !$0 { resetStep = .idle } })) {
            TextField("RESET", text: $resetConfirmation).textInputAutocapitalization(.characters)
            Button("Confirm", role: .destructive) {
                if resetConfirmation.uppercased() == "RESET" { performReset() }
                resetStep = .idle; resetConfirmation = ""
            }
            Button("Cancel", role: .cancel) { resetStep = .idle; resetConfirmation = "" }
        } message: {
            Text(resetScope == .everything
                 ? "This will permanently delete every page, habit, and completion. There is no undo."
                 : "This will permanently delete all archived pages.")
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String,
                                                @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title)
            glassGroup { content() }
        }
    }

    private func glassGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background { RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial) }
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
    }

    // MARK: - Pages

    @ViewBuilder
    private func pagesContent(settings: UserSettings) -> some View {
        ForEach(Array(pages.enumerated()), id: \.element.id) { idx, page in
            let pageHabits = (page.habits ?? []).filter { !$0.isArchived && !$0.isPaused }
            let pct = Int(stats.consistency(habits: pageHabits, window: 30) * 100)
            settingsChevronRow(
                isFirst: idx == 0,
                leading: pageIcon(page: page),
                title: page.name.titleCased,
                detail: "\(pageHabits.count) · \(pct)%"
            ) { showPages = true }
        }
        settingsChevronRow(
            isFirst: pages.isEmpty,
            isLast: true,
            leading: addPageIcon,
            title: "Add page",
            titleColor: DesignTokens.Accent.classicGreen
        ) { showPages = true }
    }

    private var addPageIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DesignTokens.Accent.classicGreen.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(DesignTokens.Accent.classicGreen.opacity(0.3),
                                      style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DesignTokens.Accent.classicGreen)
        }
        .frame(width: 30, height: 30)
    }

    private func pageIcon(page: HabitPage) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(
                    colors: [page.accentColor.opacity(0.26), page.accentColor.opacity(0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(page.accentColor.opacity(0.3), lineWidth: 1))
            Text(page.emoji).font(.system(size: 15))
        }
        .frame(width: 30, height: 30)
    }

    // MARK: - Appearance

    @ViewBuilder
    private func appearanceContent(settings: UserSettings) -> some View {
        HStack(spacing: 14) {
            Text("Theme")
                .font(.custom(FontFamily.sans, size: 15.5)).fontWeight(.semibold).kerning(-0.1)
                .foregroundColor(DesignTokens.Surface.fg())
                .frame(maxWidth: .infinity, alignment: .leading)
            displayModePicker(settings: settings)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .overlay(alignment: .bottom) { rowDivider(leading: 16) }

        HStack(spacing: 14) {
            Text("Accent")
                .font(.custom(FontFamily.sans, size: 15.5)).fontWeight(.semibold).kerning(-0.1)
                .foregroundColor(DesignTokens.Surface.fg())
                .frame(maxWidth: .infinity, alignment: .leading)
            accentPicker(settings: settings)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .overlay(alignment: .bottom) { rowDivider(leading: 16) }

        HStack(spacing: 14) {
            Text("Default page")
                .font(.custom(FontFamily.sans, size: 15.5)).fontWeight(.semibold).kerning(-0.1)
                .foregroundColor(DesignTokens.Surface.fg())
                .frame(maxWidth: .infinity, alignment: .leading)
            if !pages.isEmpty {
                Picker("", selection: Binding(
                    get: { settings.defaultPageId ?? pages.first?.id },
                    set: { settings.defaultPageId = $0 }
                )) {
                    ForEach(pages) { Text($0.name.titleCased).tag($0.id as UUID?) }
                }
                .labelsHidden()
                .tint(DesignTokens.Accent.classicGreen)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private func displayModePicker(settings: UserSettings) -> some View {
        HStack(spacing: 2) {
            ForEach(DisplayMode.allCases, id: \.self) { mode in
                DisplayModeButton(mode: mode,
                                  isSelected: settings.displayMode == mode) {
                    haptics.selection()
                    settings.displayMode = mode
                    try? repo.context.save()
                }
            }
        }
        .padding(3)
        .background(.ultraThinMaterial)
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        .clipShape(Capsule())
    }

    private func accentPicker(settings: UserSettings) -> some View {
        HStack(spacing: 5) {
            ForEach(accentColors, id: \.self) { color in
                let hex = color.toHexString()
                Circle()
                    .fill(color)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 2)
                        .opacity(settings.themeAccentHex.lowercased() == hex.lowercased() ? 1 : 0))
                    .onTapGesture {
                        haptics.selection()
                        settings.themeAccentHex = hex
                        try? repo.context.save()
                    }
            }
        }
    }

    private var accentColors: [Color] {
        [
            DesignTokens.Accent.classicGreen,
            DesignTokens.Accent.lime,
            DesignTokens.Accent.cobalt,
            DesignTokens.Accent.sunrise,
            DesignTokens.Accent.lilac,
            DesignTokens.Accent.rose,
            DesignTokens.Accent.ice
        ]
    }

    // MARK: - Behavior

    @ViewBuilder
    private func behaviorContent(settings: UserSettings) -> some View {
        settingsToggleRow(
            isFirst: true,
            icon: MiniIcon("bell.fill", color: DesignTokens.Semantic.warn),
            title: "Daily reminder",
            isOn: Binding(
                get: { settings.dailyReminderTime != nil },
                set: { on in
                    settings.dailyReminderTime = on
                        ? Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())
                        : nil
                    reschedule()
                }
            )
        )
        if settings.dailyReminderTime != nil {
            HStack(spacing: 14) {
                Text("Reminder time")
                    .font(.custom(FontFamily.sans, size: 15.5)).fontWeight(.semibold).kerning(-0.1)
                    .foregroundColor(DesignTokens.Surface.fg())
                    .frame(maxWidth: .infinity, alignment: .leading)
                DatePicker("", selection: Binding(
                    get: { settings.dailyReminderTime ?? Date() },
                    set: { settings.dailyReminderTime = $0; reschedule() }
                ), displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact).labelsHidden()
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .overlay(alignment: .bottom) { rowDivider(leading: 16) }
        }
        settingsToggleRow(
            icon: MiniIcon("waveform", color: DesignTokens.Semantic.ai),
            title: "Haptics",
            isOn: Binding(
                get: { settings.hapticsEnabled },
                set: { settings.hapticsEnabled = $0; haptics.isEnabled = $0; try? repo.context.save() }
            )
        )
        settingsToggleRow(
            icon: MiniIcon("heart.fill", color: DesignTokens.Semantic.delight),
            title: "Apple Health",
            isOn: .constant(true)
        )
        settingsToggleRow(
            icon: MiniIcon("cloud.fill", color: DesignTokens.Semantic.info),
            title: "iCloud sync",
            isOn: Binding(get: { settings.iCloudSyncEnabled }, set: { settings.iCloudSyncEnabled = $0 })
        )
        settingsToggleRow(
            isLast: true,
            icon: MiniIcon("arrow.clockwise", color: DesignTokens.Semantic.warn),
            title: "Weekly reflection",
            isOn: Binding(
                get: { settings.weeklyReflectionEnabled },
                set: { settings.weeklyReflectionEnabled = $0; reschedule() }
            )
        )
    }

    // MARK: - Danger

    @ViewBuilder
    private var dangerContent: some View {
        Button {
            haptics.warn()
            resetStep = .scope
        } label: {
            HStack {
                Text("Reset all data")
                    .font(.custom(FontFamily.sans, size: 15.5)).fontWeight(.semibold)
                    .foregroundColor(DesignTokens.Semantic.danger)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignTokens.Semantic.danger.opacity(0.6))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reset all data")
    }

    // MARK: - Row Builders

    private func settingsChevronRow(
        isFirst: Bool = false,
        isLast: Bool = false,
        leading: some View,
        title: String,
        titleColor: Color = DesignTokens.Surface.fg(),
        detail: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                leading
                Text(title)
                    .font(.custom(FontFamily.sans, size: 15.5)).fontWeight(.semibold).kerning(-0.1)
                    .foregroundColor(titleColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let detail {
                    Text(detail)
                        .font(.custom(FontFamily.sans, size: 13))
                        .foregroundColor(DesignTokens.Surface.mutedText)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignTokens.Surface.dimText)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .overlay(alignment: .bottom) { if !isLast { rowDivider(leading: 60) } }
        }
        .buttonStyle(.plain)
    }

    private func settingsToggleRow(
        isFirst: Bool = false,
        isLast: Bool = false,
        icon: some View,
        title: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 14) {
            icon
            Text(title)
                .font(.custom(FontFamily.sans, size: 15.5)).fontWeight(.semibold).kerning(-0.1)
                .foregroundColor(DesignTokens.Surface.fg())
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: isOn).labelsHidden()
                .tint(DesignTokens.Accent.classicGreen)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .overlay(alignment: .bottom) { if !isLast { rowDivider(leading: 60) } }
    }

    @ViewBuilder
    private func rowDivider(leading: CGFloat) -> some View {
        Rectangle()
            .fill(DesignTokens.Surface.hairline())
            .frame(height: 1)
            .padding(.leading, leading)
    }

    // MARK: - Actions

    private func reschedule() {
        try? repo.context.save()
        Task { await notifications.reschedule() }
    }

    private func performReset() {
        haptics.failure()
        try? repo.deleteAll(scope: resetScope == .everything ? .everything : .archivedOnly)
        if resetScope == .everything { settings = nil }
    }

    enum ResetStep { case idle, scope, confirm }
    enum ResetScope { case everything, archived }
}

// MARK: - Color → hex

private extension Color {
    func toHexString() -> String {
        let c = rgbaComponents
        return String(format: "#%02X%02X%02X",
                      Int(c.r * 255), Int(c.g * 255), Int(c.b * 255))
    }
}

private struct DisplayModeButton: View {
    let mode: DisplayMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(mode.rawValue.capitalized)
                .font(.custom(FontFamily.sans, size: 11))
                .fontWeight(.bold)
                .foregroundColor(isSelected ? .black.opacity(0.85) : DesignTokens.Surface.fgDim())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? DesignTokens.Accent.classicGreen : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
