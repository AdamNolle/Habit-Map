import Foundation

public protocol HealthKitProviding: Sendable {
    /// True if HealthKit is available on this device.
    var isAvailable: Bool { get }

    /// Current authorization state. Does NOT trigger UI; only reads cached state.
    func authState(for metrics: Set<HealthMetric>) async -> HealthAuthState

    /// Triggers the system permission sheet. Returns the resulting state.
    @discardableResult
    func requestAuthorization(for metrics: Set<HealthMetric>) async throws -> HealthAuthState

    /// Cumulative value of `metric` for the calendar day containing `date`.
    /// Steps: count. Workouts: count. Mindful: minutes. Sleep: minutes.
    /// Stand hours: hours. Active energy: kcal. Hydration: ml. Distance: meters.
    func todayTotal(for metric: HealthMetric, on date: Date) async throws -> Double
}

public enum HealthKitError: LocalizedError {
    case unavailable
    case authorizationFailed(underlying: Error?)
    case queryFailed(underlying: Error?)

    public var errorDescription: String? {
        switch self {
        case .unavailable: return "HealthKit is not available on this device."
        case .authorizationFailed(let err): return "Authorization failed: \(err?.localizedDescription ?? "unknown")"
        case .queryFailed(let err): return "Query failed: \(err?.localizedDescription ?? "unknown")"
        }
    }
}
