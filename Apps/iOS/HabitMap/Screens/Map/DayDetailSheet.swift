import SwiftUI
import SwiftData
import HabitMapCore

struct DayDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repo: HabitRepository
    @EnvironmentObject private var haptics: Haptics
    let date: Date
    let habits: [Habit]
    let accent: Color

    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    Text(headerDate)
                        .font(.custom(FontFamily.mono, size: 13))
                        .fontWeight(.semibold)
                        .foregroundColor(accent)

                    VStack(spacing: 6) {
                        ForEach(scheduled) { habit in
                            habitRow(habit)
                        }
                        if scheduled.isEmpty {
                            Text("Rest day")
                                .font(.custom(FontFamily.sans, size: 14))
                                .fontWeight(.medium)
                                .foregroundColor(DesignTokens.Surface.mutedText)
                                .padding(.vertical, 24)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note")
                            .font(.custom(FontFamily.sans, size: 11))
                            .fontWeight(.semibold)
                            .kerning(0.5)
                            .textCase(.uppercase)
                            .foregroundColor(DesignTokens.Surface.mutedText)
                        TextEditor(text: $note)
                            .scrollContentBackground(.hidden)
                            .font(.custom(FontFamily.sans, size: 15))
                            .padding(12)
                            .background(DesignTokens.Surface.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(DesignTokens.Surface.hairline(), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .frame(minHeight: 100)
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
            .background(DesignTokens.Surface.bg)
            .navigationTitle("Day")
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
    }

    private var scheduled: [Habit] {
        habits.filter { !$0.isArchived && !$0.isPaused && $0.isScheduled(date) }
    }

    private var headerDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEE · MMM d"
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
                Text(habit.name.titleCased)
                    .font(.custom(FontFamily.sans, size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(habit.accentColor)
                Text(progressLabel(habit))
                    .font(.custom(FontFamily.mono, size: 12))
                    .foregroundColor(DesignTokens.Surface.mutedText)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(DesignTokens.Surface.card)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(DesignTokens.Surface.hairline(), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func progressLabel(_ habit: Habit) -> String {
        switch habit.type {
        case .manualOnce:    return habit.progressFraction(on: date) >= 1.0 ? "Done" : "Missed"
        case .manualMultiple:
            let reps = habit.completion(on: date)?.reps ?? 0
            return "\(reps) / \(habit.targetReps)"
        case .autoHealth:
            let reps = habit.completion(on: date)?.reps ?? 0
            let goal = Int(habit.healthGoal ?? Double(habit.targetReps))
            return "\(reps) / \(goal)"
        case .inverse:
            return (habit.completion(on: date)?.slipped == true) ? "Slipped" : "Clean"
        }
    }

    private func loadNote() {
        // Read from the exact same anchor that save() writes to, so the note round-trips.
        note = scheduled.first?.completion(on: date)?.note ?? ""
    }

    private func save() {
        guard let anchor = scheduled.first else { dismiss(); return }
        do {
            try repo.setNote(note.isEmpty ? nil : note, for: anchor, on: date)
            dismiss()
        } catch {
            // Keep the sheet open so the user's note isn't silently discarded.
            haptics.warn()
        }
    }
}
