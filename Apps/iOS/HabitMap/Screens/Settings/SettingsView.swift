import SwiftUI
import SwiftData
import HabitMapCore

struct SettingsView: View {
    @EnvironmentObject private var repo: HabitRepository
    @EnvironmentObject private var notifications: NotificationCoordinator
    @Query(filter: #Predicate<HabitPage> { !$0.isArchived },
           sort: \HabitPage.sortOrder) private var pages: [HabitPage]
    @State private var settings: UserSettings?
    @State private var showPages = false
    @State private var resetStep: ResetStep = .idle
    @State private var resetScope: ResetScope = .everything
    @State private var resetConfirmation: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                PixelText("SETTINGS", pixelSize: 3, color: DesignTokens.Accent.classicGreen)
                    .accessibilityLabel("SETTINGS")
                    .accessibilityAddTraits(.isHeader)

                if let settings {
                    SettingsBody(settings: settings,
                                 pages: pages,
                                 showPages: $showPages,
                                 resetStep: $resetStep,
                                 resetScope: $resetScope,
                                 onSettingsChanged: { reschedule() })
                } else {
                    ProgressView()
                        .tint(DesignTokens.Surface.mutedText)
                        .frame(maxWidth: .infinity, minHeight: 200)
                }

                AboutSection()
            }
            .padding(DesignTokens.Spacing.md)
        }
        .background(DesignTokens.Surface.bg)
        .task {
            settings = try? repo.userSettings()
        }
        .sheet(isPresented: $showPages) {
            PagesManagerView().environmentObject(repo)
        }
        .alert("Reset what?", isPresented: Binding(get: { resetStep == .scope },
                                                   set: { if !$0 { resetStep = .idle } })) {
            Button("Everything", role: .destructive) {
                resetScope = .everything
                resetStep = .confirm
            }
            Button("Archived pages only") {
                resetScope = .archived
                resetStep = .confirm
            }
            Button("Cancel", role: .cancel) { resetStep = .idle }
        }
        .alert("Type RESET to confirm", isPresented: Binding(get: { resetStep == .confirm },
                                                             set: { if !$0 { resetStep = .idle } })) {
            TextField("RESET", text: $resetConfirmation)
                .textInputAutocapitalization(.characters)
            Button("Confirm", role: .destructive) {
                if resetConfirmation.uppercased() == "RESET" {
                    performReset()
                }
                resetStep = .idle
                resetConfirmation = ""
            }
            Button("Cancel", role: .cancel) {
                resetStep = .idle
                resetConfirmation = ""
            }
        } message: {
            Text(resetScope == .everything
                 ? "This will permanently delete every page, habit, and completion. There is no undo."
                 : "This will permanently delete all archived pages.")
        }
        .preferredColorScheme(.dark)
    }

    private func reschedule() {
        try? repo.context.save()
        Task { await notifications.reschedule() }
    }

    private func performReset() {
        try? repo.deleteAll(scope: resetScope == .everything ? .everything : .archivedOnly)
        if resetScope == .everything {
            settings = nil
        }
    }

    enum ResetStep { case idle, scope, confirm }
    enum ResetScope { case everything, archived }
}

private struct SettingsBody: View {
    @Bindable var settings: UserSettings
    let pages: [HabitPage]
    @Binding var showPages: Bool
    @Binding var resetStep: SettingsView.ResetStep
    @Binding var resetScope: SettingsView.ResetScope
    let onSettingsChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            forgivenessSection
            notificationsSection
            pagesSection
            dataSyncSection
            dangerZoneSection
        }
    }

    private var forgivenessSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("FORGIVENESS")
            ToggleRow(label: "SHOW RECOVERY RATE",
                      isOn: $settings.showRecoveryRate)
            ToggleRow(label: "REST DAYS DON'T COUNT",
                      isOn: $settings.restDaysDontCount)
            StepperRow(label: "CALM MODE THRESHOLD",
                       value: $settings.calmModeThreshold,
                       displayed: "\(Int(settings.calmModeThreshold * 100))%",
                       step: 0.05, range: 0.10...0.80)
        }
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("NOTIFICATIONS")
            HStack {
                MonoText.label("TONE")
                Spacer()
                Picker("", selection: Binding(
                    get: { settings.notificationTone },
                    set: { settings.notificationTone = $0; onSettingsChanged() })) {
                    Text("Gentle").tag(NotificationTone.gentle)
                    Text("Direct").tag(NotificationTone.direct)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(10)
            .background(DesignTokens.Surface.card)
            .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))

            ToggleRow(label: "DAILY REMINDER",
                      isOn: Binding(
                        get: { settings.dailyReminderTime != nil },
                        set: { on in
                            if on {
                                settings.dailyReminderTime = Calendar.current.date(
                                    bySettingHour: 7, minute: 0, second: 0, of: Date())
                            } else {
                                settings.dailyReminderTime = nil
                            }
                            onSettingsChanged()
                        }))
            if let time = settings.dailyReminderTime {
                HStack {
                    MonoText.label("TIME")
                    Spacer()
                    DatePicker("", selection: Binding(
                        get: { time },
                        set: { settings.dailyReminderTime = $0; onSettingsChanged() }),
                               displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                .padding(10)
                .background(DesignTokens.Surface.card)
                .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
            }
            ToggleRow(label: "WEEKLY REFLECTION",
                      isOn: Binding(
                        get: { settings.weeklyReflectionEnabled },
                        set: { settings.weeklyReflectionEnabled = $0; onSettingsChanged() }))
            ToggleRow(label: "RISK ALERTS",
                      isOn: $settings.riskAlertsEnabled)
            ToggleRow(label: "HAPTICS",
                      isOn: $settings.hapticsEnabled)
        }
    }

    private var pagesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("PAGES")
            Button { showPages = true } label: {
                HStack {
                    MonoText("MANAGE PAGES", size: .footnote, weight: .heavy,
                             color: DesignTokens.Accent.classicGreen)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(DesignTokens.Accent.classicGreen)
                }
                .padding(10)
                .background(DesignTokens.Surface.card)
                .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            if !pages.isEmpty {
                HStack {
                    MonoText.label("DEFAULT PAGE")
                    Spacer()
                    Picker("", selection: Binding(
                        get: { settings.defaultPageId ?? pages.first?.id },
                        set: { settings.defaultPageId = $0 })) {
                        ForEach(pages) { page in
                            Text(page.name).tag(page.id as UUID?)
                        }
                    }
                    .labelsHidden()
                    .tint(DesignTokens.Accent.classicGreen)
                }
                .padding(10)
                .background(DesignTokens.Surface.card)
                .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
            }
        }
    }

    private var dataSyncSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("DATA · SYNC")
            ToggleRow(label: "ICLOUD SYNC",
                      isOn: $settings.iCloudSyncEnabled)
            disabledRow(label: "APPLE HEALTH (PER-HABIT)")
            disabledRow(label: "EXPORT CSV (SOON)")
            disabledRow(label: "IMPORT / RESTORE (SOON)")
        }
    }

    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("DANGER ZONE")
            Button {
                resetStep = .scope
            } label: {
                HStack {
                    MonoText("RESET ALL DATA", size: .footnote, weight: .heavy,
                             color: DesignTokens.Surface.miss)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(DesignTokens.Surface.miss)
                }
                .padding(10)
                .background(DesignTokens.Surface.card)
                .overlay(Rectangle().stroke(DesignTokens.Surface.miss, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset all data")
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        MonoText(text, size: .caption, weight: .heavy,
                 color: DesignTokens.Accent.classicGreen)
            .padding(.top, 8)
            .padding(.leading, 2)
    }

    private func disabledRow(label: String) -> some View {
        HStack {
            MonoText(label, size: .footnote, weight: .heavy, color: DesignTokens.Surface.dimText)
            Spacer()
        }
        .padding(10)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
    }
}

// MARK: - Reusable row views

struct ToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            MonoText.label(label)
            Spacer()
            PixelToggle(isOn: $isOn)
        }
        .padding(10)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
    }
}

struct StepperRow: View {
    let label: String
    @Binding var value: Double
    let displayed: String
    let step: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            MonoText.label(label)
            Spacer()
            Stepper(displayed, value: $value, in: range, step: step)
                .labelsHidden()
            MonoText(displayed, size: .body, weight: .heavy,
                     color: DesignTokens.Accent.classicGreen)
                .frame(width: 56, alignment: .trailing)
        }
        .padding(10)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
    }
}
