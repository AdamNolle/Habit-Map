import WidgetKit
import SwiftUI
import ActivityKit
import HabitMapCore

/// Live Activity rendering for an in-progress steps habit. Lock-screen face reuses
/// the package's `StepsActivityView`; Dynamic Island is defined inline.
struct StepsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StepsActivityAttributes.self) { context in
            StepsActivityView(habitName: context.attributes.habitName,
                              accentHex: context.attributes.accentHex,
                              current: context.state.current,
                              goal: context.state.goal)
                .activityBackgroundTint(Color.black.opacity(0.25))
                .activitySystemActionForegroundColor(Color(hex: context.attributes.accentHex))
        } dynamicIsland: { context in
            let accent = Color(hex: context.attributes.accentHex)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.habitName.titleCased, systemImage: "figure.walk")
                        .font(.caption).bold()
                        .foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.fraction * 100))%")
                        .font(.caption).monospacedDigit().bold()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.fraction).tint(accent)
                }
            } compactLeading: {
                Image(systemName: "figure.walk").foregroundStyle(accent)
            } compactTrailing: {
                Text("\(Int(context.state.fraction * 100))%").monospacedDigit()
            } minimal: {
                Image(systemName: "figure.walk").foregroundStyle(accent)
            }
            .keylineTint(accent)
        }
    }
}
