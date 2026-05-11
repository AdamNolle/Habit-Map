import SwiftUI
import SwiftData
import UIKit
import HabitMapCore

struct HabitRow: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var repo: HabitRepository
    @Bindable var habit: Habit
    @State private var showDetail = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Text(habit.emoji)
                .font(.system(size: 18))
                .frame(width: 30, height: 30)
                .background(DesignTokens.Surface.tile)
                .overlay(Rectangle().stroke(DesignTokens.Surface.tileBorder, lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                PixelText(habit.name, pixelSize: 2, color: habit.accentColor)
                    .accessibilityLabel(habit.name)
                Text(subtitle)
                    .font(.system(.caption2, design: .monospaced).weight(.heavy))
                    .tracking(1.0)
                    .foregroundColor(DesignTokens.Surface.mutedText)
                MiniHeatmap(habit: habit)
            }

            Spacer()

            HabitCell(level: habit.cellLevel(on: Date()),
                      accent: habit.accentColor,
                      isToday: true,
                      size: 36)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .onTapGesture { handleTap() }
                .accessibilityElement()
                .accessibilityLabel("\(habit.name), \(subtitle)")
                .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 2))
        .contextMenu {
            Button {
                showDetail = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                try? repo.deleteHabit(habit)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showDetail) {
            HabitDetailView(habit: habit).environmentObject(repo)
        }
    }

    private var subtitle: String {
        switch habit.type {
        case .manualOnce:
            return habit.progressFraction(on: Date()) >= 1.0 ? "DONE" : "TAP TO LOG"
        case .manualMultiple:
            let reps = habit.completion(on: Date())?.reps ?? 0
            return "\(reps) / \(habit.targetReps)"
        case .autoHealth:
            let reps = habit.completion(on: Date())?.reps ?? 0
            let goal = Int(habit.healthGoal ?? Double(habit.targetReps))
            return "\(reps) / \(goal)"
        case .inverse:
            return (habit.completion(on: Date())?.slipped == true) ? "SLIPPED" : "CLEAN"
        }
    }

    private func handleTap() {
        let today = Date.startOfToday()
        let existing = habit.completion(on: today)
        switch habit.type {
        case .manualOnce:
            if let existing {
                existing.reps = existing.reps >= 1 ? 0 : 1
                existing.loggedAt = Date()
            } else {
                modelContext.insert(HabitCompletion(date: today, reps: 1, habit: habit))
            }
        case .manualMultiple:
            if let existing {
                existing.reps = existing.reps >= habit.targetReps ? 0 : existing.reps + 1
                existing.loggedAt = Date()
            } else {
                modelContext.insert(HabitCompletion(date: today, reps: 1, habit: habit))
            }
        case .inverse:
            if let existing {
                existing.slipped.toggle()
                existing.loggedAt = Date()
            } else {
                modelContext.insert(HabitCompletion(date: today, slipped: true, habit: habit))
            }
        case .autoHealth:
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        try? modelContext.save()
    }
}
