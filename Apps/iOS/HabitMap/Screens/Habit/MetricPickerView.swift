import SwiftUI
import HabitMapCore

struct MetricOption: Identifiable, Hashable {
    let id: HealthMetric
    let label: String
    let emoji: String
    let defaultGoal: Double
    let unit: String
}

struct MetricPickerView: View {
    @Binding var metric: HealthMetric?
    @Binding var goal: Double
    let accent: Color

    static let options: [MetricOption] = [
        .init(id: .stepCount, label: "Steps", emoji: "👟", defaultGoal: 10000, unit: "steps"),
        .init(id: .workouts, label: "Workouts", emoji: "🏋️", defaultGoal: 1, unit: "sessions"),
        .init(id: .mindfulMinutes, label: "Mindful", emoji: "🧘", defaultGoal: 10, unit: "minutes"),
        .init(id: .sleep, label: "Sleep", emoji: "💤", defaultGoal: 420, unit: "minutes"),
        .init(id: .standHours, label: "Stand", emoji: "🧍", defaultGoal: 12, unit: "hours"),
        .init(id: .activeEnergy, label: "Calories", emoji: "🔥", defaultGoal: 500, unit: "kcal"),
        .init(id: .hydration, label: "Hydration", emoji: "💧", defaultGoal: 2000, unit: "ml"),
        .init(id: .distanceWalkingRunning, label: "Distance", emoji: "🏃", defaultGoal: 5000, unit: "meters")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(Self.options) { opt in
                    let selected = metric == opt.id
                    Button {
                        metric = opt.id
                        goal = opt.defaultGoal
                    } label: {
                        VStack(spacing: 6) {
                            Text(opt.emoji).font(.system(size: 22))
                            Text(opt.label)
                                .font(.custom(FontFamily.sans, size: 12))
                                .fontWeight(.semibold)
                                .foregroundColor(selected ? .black : accent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selected ? accent : DesignTokens.Surface.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(selected ? accent.darker(by: 0.2) : DesignTokens.Surface.hairline(), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(opt.label)
                    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                }
            }

            if let selected = metric, let opt = Self.options.first(where: { $0.id == selected }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily goal")
                        .font(.custom(FontFamily.sans, size: 11))
                        .fontWeight(.semibold)
                        .kerning(0.5)
                        .textCase(.uppercase)
                        .foregroundColor(DesignTokens.Surface.mutedText)
                    HStack(spacing: DesignTokens.Spacing.md) {
                        AppButton("−", style: .glass, accent: accent) {
                            goal = max(stepIncrement(for: opt), goal - stepIncrement(for: opt))
                        }.frame(width: 56)
                        VStack(spacing: 2) {
                            Text("\(Int(goal))")
                                .font(.custom(FontFamily.mono, size: 28))
                                .fontWeight(.bold)
                                .foregroundColor(accent)
                            Text(opt.unit)
                                .font(.custom(FontFamily.sans, size: 11))
                                .fontWeight(.medium)
                                .foregroundColor(DesignTokens.Surface.mutedText)
                        }
                        .frame(maxWidth: .infinity)
                        AppButton("+", style: .glass, accent: accent) {
                            goal += stepIncrement(for: opt)
                        }.frame(width: 56)
                    }
                }
            }
        }
    }

    private func stepIncrement(for opt: MetricOption) -> Double {
        switch opt.id {
        case .stepCount: return 500
        case .workouts: return 1
        case .mindfulMinutes, .sleep, .standHours: return 5
        case .activeEnergy: return 50
        case .hydration: return 250
        case .distanceWalkingRunning: return 500
        case .heartRate: return 1
        }
    }
}
