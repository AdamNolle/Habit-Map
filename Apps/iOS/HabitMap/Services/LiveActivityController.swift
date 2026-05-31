import Foundation
import ActivityKit
import HabitMapCore

/// Starts/updates/ends the steps Live Activity. The integration point for an
/// in-progress `.autoHealth` steps habit.
///
/// Runtime behaviour is device-only: the simulator builds this but never renders
/// a Live Activity. Auto-triggering on live HealthKit step deltas is a follow-up;
/// today this is the explicit API a caller (or a debug action) invokes.
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()
    private init() {}

    private var activity: Activity<StepsActivityAttributes>?

    var isSupported: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    @discardableResult
    func start(habitName: String, accentHex: String, current: Int, goal: Int) -> Bool {
        guard isSupported, activity == nil else { return false }
        let attributes = StepsActivityAttributes(habitName: habitName, accentHex: accentHex)
        let state = StepsActivityAttributes.ContentState(current: current, goal: goal)
        activity = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil)
        )
        return activity != nil
    }

    func update(current: Int, goal: Int) {
        guard let activity else { return }
        let state = StepsActivityAttributes.ContentState(current: current, goal: goal)
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func end() {
        guard let activity else { return }
        let final = activity
        self.activity = nil
        Task { await final.end(nil, dismissalPolicy: .immediate) }
    }
}
