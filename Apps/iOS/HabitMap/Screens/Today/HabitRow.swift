import SwiftUI
import SwiftData
import UIKit
import HabitMapCore

struct HabitRow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var repo: HabitRepository
    @EnvironmentObject private var sync: HealthSyncService
    @EnvironmentObject private var haptics: Haptics
    @Bindable var habit: Habit
    let index: Int
    @State private var showDetail = false
    @State private var healthAuth: HealthAuthState = .undetermined

    init(habit: Habit, index: Int) {
        self.habit = habit
        self.index = index
    }

    private var isDone: Bool { habit.progressFraction(on: Date()) >= 1.0 }

    var body: some View {
        HStack(spacing: 14) {
            Text(String(format: "%02d", index + 1))
                .font(.custom(FontFamily.mono, size: 12))
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundColor(isDone ? habit.accentColor : DesignTokens.Surface.dimText)
                .frame(minWidth: 20, alignment: .trailing)
                .animation(.easeInOut(duration: 0.25), value: isDone)

            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isDone
                        ? AnyShapeStyle(LinearGradient(
                            colors: [habit.accentColor.lighter(by: 0.08), habit.accentColor.darker(by: 0.04)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(
                                isDone ? habit.accentColor.darker(by: 0.22) : DesignTokens.Surface.hairline(),
                                lineWidth: 1
                            )
                    )
                Image(systemName: HabitIcon.symbol(for: habit.name))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isDone ? Color(hex: "#0a1a0a") : DesignTokens.Surface.mutedText)
            }
            .frame(width: 32, height: 32)
            .shadow(color: isDone ? habit.accentColor.opacity(0.4) : .clear, radius: 8, x: 0, y: 4)
            .animation(.easeInOut(duration: 0.25), value: isDone)

            Text(habit.name.titleCased)
                .font(.custom(FontFamily.sans, size: 16))
                .fontWeight(.semibold)
                .kerning(-0.3)
                .foregroundColor(DesignTokens.Surface.fg())
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(qtyLabel)
                    .font(.custom(FontFamily.mono, size: 13))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundColor(isDone ? habit.accentColor : DesignTokens.Surface.mutedText)
                if !unitLabel.isEmpty {
                    Text(unitLabel)
                        .font(.custom(FontFamily.sans, size: 11))
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Surface.dimText)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isDone)

            HabitCell(level: habit.cellLevel(on: Date()),
                      accent: habit.accentColor,
                      isToday: true,
                      size: 30,
                      radius: 7)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
                .onTapGesture { handleTap() }
                .accessibilityElement()
                .accessibilityLabel("\(habit.name), \(qtyLabel)")
                .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .onTapGesture { showDetail = true }
        .contextMenu {
            Button { showDetail = true } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) {
                haptics.failure()
                try? repo.deleteHabit(habit)
            } label: { Label("Delete", systemImage: "trash") }
        }
        .sheet(isPresented: $showDetail) {
            HabitDetailView(habit: habit)
                .environmentObject(repo)
                .environmentObject(haptics)
        }
        .task {
            if habit.type == .autoHealth, let metric = habit.healthMetric {
                healthAuth = await sync.provider.authState(for: [metric])
            }
        }
    }

    private var qtyLabel: String {
        switch habit.type {
        case .manualOnce:
            return isDone ? "Done" : "—"
        case .manualMultiple:
            let reps = habit.completion(on: Date())?.reps ?? 0
            return "\(reps) / \(habit.targetReps)"
        case .autoHealth:
            switch healthAuth {
            case .unavailable: return "Unavailable"
            case .undetermined: return "Authorize"
            case .denied(let n): return n < 2 ? "Authorize" : "Settings"
            case .authorized:
                let reps = habit.completion(on: Date())?.reps ?? 0
                let goal = Int(habit.healthGoal ?? Double(habit.targetReps))
                return "\(reps) / \(goal)"
            }
        case .inverse:
            if let c = habit.completion(on: Date()), c.slipped { return "Slipped" }
            return "Clean"
        }
    }

    private var unitLabel: String {
        switch habit.type {
        case .manualMultiple: return ""
        case .autoHealth:
            if case .authorized = healthAuth {
                return habit.healthMetric?.displayUnit ?? ""
            }
            return ""
        default: return ""
        }
    }

    private func handleTap() {
        if habit.type == .autoHealth {
            handleAutoHealthTap()
            return
        }
        let today = Date.startOfToday()
        let existing = habit.completion(on: today)
        let wasComplete = isDone

        // Snapshot for revert if the save fails (don't persist a lie).
        let priorReps = existing?.reps
        let priorSlipped = existing?.slipped
        let priorLoggedAt = existing?.loggedAt
        var inserted: HabitCompletion?
        let onSuccess: () -> Void

        switch habit.type {
        case .manualOnce:
            if let existing {
                existing.reps = existing.reps >= 1 ? 0 : 1
                existing.loggedAt = Date()
            } else {
                let c = HabitCompletion(date: today, reps: 1, habit: habit)
                modelContext.insert(c)
                inserted = c
            }
            onSuccess = { if wasComplete { haptics.habitUncomplete() } else { haptics.habitComplete() } }

        case .manualMultiple:
            let newReps: Int
            if let existing {
                newReps = existing.reps >= habit.targetReps ? 0 : existing.reps + 1
                existing.reps = newReps
                existing.loggedAt = Date()
            } else {
                newReps = 1
                let c = HabitCompletion(date: today, reps: 1, habit: habit)
                modelContext.insert(c)
                inserted = c
            }
            onSuccess = { haptics.multiStep(step: newReps, of: habit.targetReps) }

        case .inverse:
            if let existing {
                existing.slipped.toggle()
                existing.loggedAt = Date()
            } else {
                let c = HabitCompletion(date: today, slipped: true, habit: habit)
                modelContext.insert(c)
                inserted = c
            }
            onSuccess = { if wasComplete { haptics.habitUncomplete() } else { haptics.habitComplete() } }

        case .autoHealth:
            return
        }

        do {
            try modelContext.save()
            onSuccess()
        } catch {
            // Revert the optimistic mutation so the UI doesn't show an unsaved change.
            if let inserted {
                modelContext.delete(inserted)
            } else if let existing {
                if let priorReps { existing.reps = priorReps }
                if let priorSlipped { existing.slipped = priorSlipped }
                if let priorLoggedAt { existing.loggedAt = priorLoggedAt }
            }
            haptics.warn()
        }
    }

    private func handleAutoHealthTap() {
        guard let metric = habit.healthMetric else { return }
        switch healthAuth {
        case .undetermined:
            Task {
                do {
                    let newState = try await sync.provider.requestAuthorization(for: [metric])
                    healthAuth = newState
                    if case .authorized = newState { await sync.syncHabit(habit) } else if case .denied = newState { healthAuth = .denied(timesDenied: 1) }
                } catch { healthAuth = .denied(timesDenied: 1) }
            }
        case .denied(let n) where n < 2:
            Task {
                do {
                    let newState = try await sync.provider.requestAuthorization(for: [metric])
                    healthAuth = newState
                    if case .authorized = newState { await sync.syncHabit(habit) } else { healthAuth = .denied(timesDenied: n + 1) }
                } catch { healthAuth = .denied(timesDenied: n + 1) }
            }
        case .denied:
            // Authorization is exhausted (denied twice). iOS won't re-prompt, so
            // deep-link to system Settings where the user can re-grant access.
            // Do NOT silently rewrite the habit's type/metric.
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        case .authorized:
            Task { await sync.syncHabit(habit) }
        case .unavailable:
            break
        }
    }
}

private extension HealthMetric {
    var displayUnit: String {
        switch self {
        case .stepCount:               return "steps"
        case .workouts:                return "min"
        case .mindfulMinutes:          return "min"
        case .sleep:                   return "hrs"
        case .standHours:              return "hrs"
        case .activeEnergy:            return "cal"
        case .hydration:               return "L"
        case .distanceWalkingRunning:  return "km"
        case .heartRate:               return "bpm"
        }
    }
}
