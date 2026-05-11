import Foundation

/// In-memory fake for tests + previews.
public final class MockHealthKitProvider: HealthKitProviding, @unchecked Sendable {
    public var isAvailable: Bool
    public var stubAuthState: HealthAuthState
    public var todayValues: [HealthMetric: Double]
    public var requestAuthCallCount: Int = 0
    public var lastRequestedMetrics: Set<HealthMetric> = []
    public var queriedMetrics: [HealthMetric] = []

    public init(isAvailable: Bool = true,
                stubAuthState: HealthAuthState = .authorized,
                todayValues: [HealthMetric: Double] = [:]) {
        self.isAvailable = isAvailable
        self.stubAuthState = stubAuthState
        self.todayValues = todayValues
    }

    public func authState(for metrics: Set<HealthMetric>) async -> HealthAuthState {
        if !isAvailable { return .unavailable }
        return stubAuthState
    }

    @discardableResult
    public func requestAuthorization(for metrics: Set<HealthMetric>) async throws -> HealthAuthState {
        requestAuthCallCount += 1
        lastRequestedMetrics = metrics
        if !isAvailable { throw HealthKitError.unavailable }
        return stubAuthState
    }

    public func todayTotal(for metric: HealthMetric, on date: Date) async throws -> Double {
        queriedMetrics.append(metric)
        if !isAvailable { throw HealthKitError.unavailable }
        return todayValues[metric] ?? 0
    }
}
