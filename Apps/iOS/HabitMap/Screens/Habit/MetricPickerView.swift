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
        .init(id: .stepCount, label: "STEPS", emoji: "👟", defaultGoal: 10000, unit: "steps"),
        .init(id: .workouts, label: "WORKOUTS", emoji: "🏋️", defaultGoal: 1, unit: "sessions"),
        .init(id: .mindfulMinutes, label: "MINDFUL", emoji: "🧘", defaultGoal: 10, unit: "minutes"),
        .init(id: .sleep, label: "SLEEP", emoji: "💤", defaultGoal: 420, unit: "minutes"),
        .init(id: .standHours, label: "STAND", emoji: "🧍", defaultGoal: 12, unit: "hours"),
        .init(id: .activeEnergy, label: "CALORIES", emoji: "🔥", defaultGoal: 500, unit: "kcal"),
        .init(id: .hydration, label: "HYDRATION", emoji: "💧", defaultGoal: 2000, unit: "ml"),
        .init(id: .distanceWalkingRunning, label: "DISTANCE", emoji: "🏃", defaultGoal: 5000, unit: "meters")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), spacing: 6) {
                ForEach(Self.options) { opt in
                    Button {
                        metric = opt.id
                        goal = opt.defaultGoal
                    } label: {
                        VStack(spacing: 4) {
                            Text(opt.emoji).font(.system(size: 22))
                            MonoText(opt.label, size: .caption, weight: .heavy,
                                     color: metric == opt.id ? .black : accent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(metric == opt.id ? accent : DesignTokens.Surface.tile)
                        .overlay(Rectangle().stroke(metric == opt.id ? accent.darker(by: 0.2) : DesignTokens.Surface.tileBorder,
                                                   lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(opt.label)
                    .accessibilityAddTraits(metric == opt.id ? [.isButton, .isSelected] : .isButton)
                }
            }

            if let selected = metric, let opt = Self.options.first(where: { $0.id == selected }) {
                VStack(alignment: .leading, spacing: 8) {
                    MonoText.label("DAILY GOAL")
                    HStack(spacing: DesignTokens.Spacing.md) {
                        PixelButton("−", style: .secondary, accent: accent) {
                            goal = max(stepIncrement(for: opt), goal - stepIncrement(for: opt))
                        }.frame(width: 56)
                        VStack(spacing: 2) {
                            MonoText("\(Int(goal))", size: .title, weight: .heavy, color: accent)
                            MonoText(opt.unit.uppercased(), size: .caption, weight: .heavy,
                                     color: DesignTokens.Surface.mutedText)
                        }
                        .frame(maxWidth: .infinity)
                        PixelButton("+", style: .secondary, accent: accent) {
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
