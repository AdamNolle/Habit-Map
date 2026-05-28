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

                    fieldSection("Name") {
                        TextField("e.g. Drink Water", text: $habit.name)
                            .textInputAutocapitalization(.words)
                            .glassTextField()
                    }

                    fieldSection("Emoji") {
                        EmojiPicker(selected: $habit.emoji, accent: habit.accentColor)
                    }

                    fieldSection("Accent") {
                        AccentSwatchPicker(selectedHex: $habit.accentHex)
                    }

                    fieldSection("Days") {
                        WeekdayPicker(mask: $habit.weekdayMask, accent: habit.accentColor)
                    }

                    if habit.type == .manualMultiple {
                        fieldSection("Target reps") {
                            HStack {
                                Stepper("\(habit.targetReps)", value: $habit.targetReps, in: 1...20)
                                    .labelsHidden()
                                Spacer()
                                Text("\(habit.targetReps)")
                                    .font(.custom(FontFamily.mono, size: 17))
                                    .fontWeight(.bold)
                                    .foregroundColor(habit.accentColor)
                            }
                            .glassField()
                        }
                    }

                    VStack(spacing: 10) {
                        if habit.isArchived {
                            AppButton("Unarchive", style: .glass, accent: habit.accentColor) {
                                habit.isArchived = false
                                try? repo.context.save()
                            }
                        } else {
                            AppButton("Archive", style: .glass, accent: habit.accentColor) {
                                try? repo.archiveHabit(habit)
                                dismiss()
                            }
                        }
                        AppButton("Delete", style: .destructive) { showDeleteAlert = true }
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
            .background(DesignTokens.Surface.bg)
            .navigationTitle("Habit")
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
    }

    @ViewBuilder
    private func fieldSection<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.custom(FontFamily.sans, size: 11))
                .fontWeight(.semibold)
                .kerning(0.5)
                .textCase(.uppercase)
                .foregroundColor(DesignTokens.Surface.mutedText)
            content()
        }
    }
}

private extension View {
    func glassTextField() -> some View {
        self
            .font(.custom(FontFamily.sans, size: 16))
            .fontWeight(.medium)
            .padding(12)
            .background(DesignTokens.Surface.card)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(DesignTokens.Surface.hairline(), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    func glassField() -> some View {
        self
            .padding(12)
            .background(DesignTokens.Surface.card)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(DesignTokens.Surface.hairline(), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
