import SwiftUI
import SwiftData
import HabitMapCore

struct HabitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repo: HabitRepository
    @Bindable var habit: Habit

    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    HStack {
                        Spacer()
                        PixelRing(filledSegments: PixelRing.segments(for: habit.progressFraction(on: Date())),
                                  accent: habit.accentColor)
                            .frame(width: 180, height: 180)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        MonoText.label("NAME")
                        TextField("name", text: $habit.name)
                            .textInputAutocapitalization(.characters)
                            .font(.system(.body, design: .monospaced).weight(.heavy))
                            .padding(10)
                            .background(DesignTokens.Surface.tile)
                            .overlay(Rectangle().stroke(DesignTokens.Surface.tileBorder, lineWidth: 2))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        MonoText.label("EMOJI")
                        EmojiPicker(selected: $habit.emoji, accent: habit.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        MonoText.label("ACCENT")
                        AccentSwatchPicker(selectedHex: $habit.accentHex)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        MonoText.label("DAYS")
                        WeekdayPicker(mask: $habit.weekdayMask, accent: habit.accentColor)
                    }

                    if habit.type == .manualMultiple {
                        VStack(alignment: .leading, spacing: 8) {
                            MonoText.label("TARGET REPS")
                            HStack {
                                Stepper("\(habit.targetReps)", value: $habit.targetReps, in: 1...20)
                                    .labelsHidden()
                                Spacer()
                                MonoText("\(habit.targetReps)", size: .body, weight: .heavy,
                                         color: habit.accentColor)
                            }
                            .padding(10)
                            .background(DesignTokens.Surface.tile)
                            .overlay(Rectangle().stroke(DesignTokens.Surface.tileBorder, lineWidth: 2))
                        }
                    }

                    VStack(spacing: 10) {
                        if habit.isArchived {
                            PixelButton("UNARCHIVE", style: .secondary, accent: habit.accentColor) {
                                habit.isArchived = false
                                try? repo.context.save()
                            }
                        } else {
                            PixelButton("ARCHIVE", style: .secondary, accent: habit.accentColor) {
                                try? repo.archiveHabit(habit)
                                dismiss()
                            }
                        }
                        PixelButton("DELETE", style: .destructive) { showDeleteAlert = true }
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
            .background(DesignTokens.Surface.bg)
            .navigationTitle("HABIT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        try? repo.context.save()
                        dismiss()
                    }
                }
            }
            .alert("Delete this habit?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    try? repo.deleteHabit(habit)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("All completion history will be permanently removed.")
            }
        }
        .preferredColorScheme(.dark)
    }
}
