import SwiftUI
import SwiftData
import UIKit
import HabitMapCore

struct HabitRow: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var repo: HabitRepository
    @EnvironmentObject private var sync: HealthSyncService
    @Query private var allSettings: [UserSettings]
    @Bindable var habit: Habit
    @State private var showDetail = false
    @State private var healthAuth: HealthAuthState = .undetermined

    private var hapticsEnabled: Bool {
        allSettings.first?.hapticsEnabled ?? true
    }

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
            Button { showDetail = true } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) {
                try? repo.deleteHabit(habit)
            } label: { Label("Delete", systemImage: "trash") }
        }
        .sheet(isPresented: $showDetail) {
            HabitDetailView(habit: habit).environmentObject(repo)
        }
        .task {
            if habit.type == .autoHealth, let metric = habit.healthMetric {
                healthAuth = await sync.provider.authState(for: [metric])
            }
        }
    }

    private var subtitle: String {
        if habit.type == .autoHealth {
            switch healthAuth {
            case .unavailable:
                return "HEALTH UNAVAILABLE"
            case .undetermined:
                return "TAP TO AUTHORIZE"
            case .denied(let n) where n < 2:
                return "TAP TO AUTHORIZE"
            case .denied:
                return "SWITCH TO MANUAL?"
            case .authorized:
                let reps = habit.completion(on: Date())?.reps ?? 0
                let goal = Int(habit.healthGoal ?? Double(habit.targetReps))
                return "\(reps) / \(goal)"
            }
        }
        switch habit.type {
        case .manualOnce:
            return habit.progressFraction(on: Date()) >= 1.0 ? "DONE" : "TAP TO LOG"
        case .manualMultiple:
            let reps = habit.completion(on: Date())?.reps ?? 0
            return "\(reps) / \(habit.targetReps)"
        case .autoHealth:
            return ""
        case .inverse:
            return (habit.completion(on: Date())?.slipped == true) ? "SLIPPED" : "CLEAN"
        }
    }

    private func handleTap() {
        if habit.type == .autoHealth {
            handleAutoHealthTap()
            return
        }
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
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        try? modelContext.save()
    }

    private func handleAutoHealthTap() {
        guard let metric = habit.healthMetric else { return }
        switch healthAuth {
        case .undetermined:
            Task {
                do {
                    let newState = try await sync.provider.requestAuthorization(for: [metric])
                    healthAuth = newState
                    if case .authorized = newState {
                        await sync.syncHabit(habit)
                    } else if case .denied = newState {
                        healthAuth = .denied(timesDenied: 1)
                    }
                } catch {
                    healthAuth = .denied(timesDenied: 1)
                }
            }
        case .denied(let n) where n < 2:
            Task {
                do {
                    let newState = try await sync.provider.requestAuthorization(for: [metric])
                    healthAuth = newState
                    if case .authorized = newState {
                        await sync.syncHabit(habit)
                    } else {
                        healthAuth = .denied(timesDenied: n + 1)
                    }
                } catch {
                    healthAuth = .denied(timesDenied: n + 1)
                }
            }
        case .denied:
            // Second denial: convert to manual.
            habit.type = .manualOnce
            habit.healthMetric = nil
            try? modelContext.save()
        case .authorized:
            Task { await sync.syncHabit(habit) }
        case .unavailable:
            break
        }
    }
}
