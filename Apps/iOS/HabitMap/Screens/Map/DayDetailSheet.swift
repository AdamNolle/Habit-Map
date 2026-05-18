import SwiftUI
import SwiftData
import HabitMapCore

struct DayDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repo: HabitRepository
    let date: Date
    let habits: [Habit]
    let accent: Color

    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    PixelText(headerDate, pixelSize: 3, color: accent)

                    VStack(spacing: 6) {
                        ForEach(scheduled) { habit in
                            habitRow(habit)
                        }
                        if scheduled.isEmpty {
                            MonoText("REST DAY", size: .footnote, weight: .heavy,
                                     color: DesignTokens.Surface.mutedText)
                                .padding(.vertical, 24)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        MonoText.label("NOTE")
                        TextEditor(text: $note)
                            .scrollContentBackground(.hidden)
                            .background(DesignTokens.Surface.tile)
                            .overlay(Rectangle().stroke(DesignTokens.Surface.tileBorder, lineWidth: 2))
                            .frame(minHeight: 100)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
            .background(DesignTokens.Surface.bg)
            .navigationTitle("DAY")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear { loadNote() }
        }
        .preferredColorScheme(.dark)
    }

    private var scheduled: [Habit] {
        habits.filter { !$0.isArchived && !$0.isPaused && $0.isScheduled(date) }
    }

    private var headerDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEE - MMM d"
        return f.string(from: date).uppercased()
    }

    @ViewBuilder
    private func habitRow(_ habit: Habit) -> some View {
        HStack(spacing: 10) {
            HabitCell(level: habit.cellLevel(on: date),
                      accent: habit.accentColor,
                      isToday: Calendar.current.isDateInToday(date),
                      size: 28)
            VStack(alignment: .leading, spacing: 2) {
                MonoText(habit.name, size: .footnote, weight: .heavy, color: habit.accentColor)
                MonoText(progressLabel(habit), size: .caption, weight: .heavy,
                         color: DesignTokens.Surface.mutedText)
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
    }

    private func progressLabel(_ habit: Habit) -> String {
        switch habit.type {
        case .manualOnce:    return habit.progressFraction(on: date) >= 1.0 ? "DONE" : "MISSED"
        case .manualMultiple:
            let reps = habit.completion(on: date)?.reps ?? 0
            return "\(reps) / \(habit.targetReps)"
        case .autoHealth:
            let reps = habit.completion(on: date)?.reps ?? 0
            let goal = Int(habit.healthGoal ?? Double(habit.targetReps))
            return "\(reps) / \(goal)"
        case .inverse:
            return (habit.completion(on: date)?.slipped == true) ? "SLIPPED" : "CLEAN"
        }
    }

    private func loadNote() {
        for habit in habits {
            if let n = habit.completion(on: date)?.note, !n.isEmpty {
                note = n
                return
            }
        }
        note = ""
    }

    private func save() {
        guard let anchor = scheduled.first else { dismiss(); return }
        if let existing = anchor.completion(on: date) {
            existing.note = note.isEmpty ? nil : note
        } else {
            let completion = HabitCompletion(date: date, reps: 0, note: note.isEmpty ? nil : note, habit: anchor)
            repo.context.insert(completion)
        }
        try? repo.context.save()
        dismiss()
    }
}
