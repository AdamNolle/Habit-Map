import SwiftUI
import HabitMapCore

struct WizardDraft {
    var name: String = ""
    var emoji: String = "💧"
    var accentHex: String = "#3DA4FF"
    var type: HabitType = .manualMultiple
    var targetReps: Int = 1
    var weekdayMask: Int8 = 0b01111111
    var restDayMask: Int8 = 0
    var reminderEnabled: Bool = false
    var reminderTime: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    var healthMetric: HealthMetric? = nil
    var healthGoal: Double = 10000
}

struct AddHabitWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repo: HabitRepository
    @EnvironmentObject private var haptics: Haptics
    let page: HabitPage

    @State private var step: Int = 0
    @State private var draft = WizardDraft()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WizardProgressBar(currentStep: step, totalSteps: 3, accent: page.accentColor)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.top, DesignTokens.Spacing.md)

                ScrollView {
                    Group {
                        switch step {
                        case 0: AddHabitStep1View(draft: $draft, pageAccent: page.accentColor)
                        case 1: AddHabitStep2View(draft: $draft, pageAccent: page.accentColor)
                        default: AddHabitStep3View(draft: $draft, pageAccent: page.accentColor)
                        }
                    }
                    .padding(DesignTokens.Spacing.lg)
                }

                HStack(spacing: DesignTokens.Spacing.md) {
                    if step > 0 {
                        AppButton("BACK", style: .glass, accent: page.accentColor) {
                            haptics.wizardStep()
                            step -= 1
                        }
                    }
                    AppButton(step == 2 ? "CREATE" : "NEXT",
                                accent: page.accentColor,
                                isEnabled: canAdvance) {
                        if step < 2 { haptics.wizardStep(); step += 1 } else { create() }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .background(DesignTokens.Surface.bg)
            .navigationTitle("NEW HABIT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 0: return !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1:
            if draft.type == .autoHealth { return draft.healthMetric != nil }
            return draft.targetReps >= 1 || draft.type == .inverse || draft.type == .manualOnce
        default: return draft.weekdayMask != 0
        }
    }

    private func create() {
        let reps: Int
        switch draft.type {
        case .manualOnce: reps = 1
        case .inverse: reps = 0
        case .manualMultiple: reps = draft.targetReps
        case .autoHealth: reps = Int(draft.healthGoal)
        }
        let habit = try? repo.createHabit(name: draft.name,
                                          emoji: draft.emoji,
                                          accentHex: draft.accentHex,
                                          type: draft.type,
                                          targetReps: reps,
                                          weekdayMask: draft.weekdayMask,
                                          restDayMask: draft.restDayMask,
                                          reminderTime: draft.reminderEnabled ? draft.reminderTime : nil,
                                          on: page)
        if draft.type == .autoHealth, let habit {
            habit.healthMetric = draft.healthMetric
            habit.healthGoal = draft.healthGoal
            try? repo.context.save()
        }
        haptics.success()
        dismiss()
    }
}
