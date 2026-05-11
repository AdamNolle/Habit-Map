import Foundation
import HealthKit

public final class HealthKitService: HealthKitProviding, @unchecked Sendable {
    private let store: HKHealthStore?

    public init() {
        self.store = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }

    public var isAvailable: Bool { store != nil }

    public func authState(for metrics: Set<HealthMetric>) async -> HealthAuthState {
        guard let store else { return .unavailable }
        let types = metrics.compactMap(Self.objectType(for:))
        guard !types.isEmpty else { return .undetermined }
        let statuses = types.map { store.authorizationStatus(for: $0) }
        if statuses.allSatisfy({ $0 == .sharingAuthorized }) { return .authorized }
        if statuses.contains(.sharingDenied) { return .denied(timesDenied: 1) }
        return .undetermined
    }

    @discardableResult
    public func requestAuthorization(for metrics: Set<HealthMetric>) async throws -> HealthAuthState {
        guard let store else { throw HealthKitError.unavailable }
        let types = Set(metrics.compactMap(Self.objectType(for:)))
        guard !types.isEmpty else { return .undetermined }
        do {
            try await store.requestAuthorization(toShare: [], read: types)
            return await authState(for: metrics)
        } catch {
            throw HealthKitError.authorizationFailed(underlying: error)
        }
    }

    public func todayTotal(for metric: HealthMetric, on date: Date) async throws -> Double {
        guard let store else { throw HealthKitError.unavailable }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            throw HealthKitError.queryFailed(underlying: nil)
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        if let qt = Self.quantityType(for: metric), let unit = Self.unit(for: metric) {
            return try await sumQuantity(type: qt, unit: unit, predicate: predicate, on: store)
        }
        if metric == .workouts {
            return try await workoutCount(predicate: predicate, on: store)
        }
        if metric == .mindfulMinutes {
            return try await mindfulMinutes(predicate: predicate, on: store)
        }
        if metric == .sleep {
            return try await sleepMinutes(predicate: predicate, on: store)
        }
        throw HealthKitError.queryFailed(underlying: nil)
    }

    // MARK: - Static maps

    public static func objectType(for metric: HealthMetric) -> HKObjectType? {
        switch metric {
        case .stepCount: return HKQuantityType(.stepCount)
        case .activeEnergy: return HKQuantityType(.activeEnergyBurned)
        case .standHours: return HKQuantityType(.appleStandTime)
        case .hydration: return HKQuantityType(.dietaryWater)
        case .distanceWalkingRunning: return HKQuantityType(.distanceWalkingRunning)
        case .heartRate: return HKQuantityType(.heartRate)
        case .workouts: return HKWorkoutType.workoutType()
        case .mindfulMinutes: return HKCategoryType(.mindfulSession)
        case .sleep: return HKCategoryType(.sleepAnalysis)
        }
    }

    public static func quantityType(for metric: HealthMetric) -> HKQuantityType? {
        objectType(for: metric) as? HKQuantityType
    }

    public static func unit(for metric: HealthMetric) -> HKUnit? {
        switch metric {
        case .stepCount: return .count()
        case .activeEnergy: return .kilocalorie()
        case .standHours: return .hour()
        case .hydration: return .literUnit(with: .milli)
        case .distanceWalkingRunning: return .meter()
        case .heartRate: return HKUnit.count().unitDivided(by: .minute())
        case .workouts, .mindfulMinutes, .sleep: return nil
        }
    }

    // MARK: - Query primitives

    private func sumQuantity(type: HKQuantityType,
                             unit: HKUnit,
                             predicate: NSPredicate,
                             on store: HKHealthStore) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let q = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, stats, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(underlying: error))
                    return
                }
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(q)
        }
    }

    private func workoutCount(predicate: NSPredicate, on store: HKHealthStore) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let q = HKSampleQuery(sampleType: HKWorkoutType.workoutType(),
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(underlying: error))
                    return
                }
                continuation.resume(returning: Double(samples?.count ?? 0))
            }
            store.execute(q)
        }
    }

    private func mindfulMinutes(predicate: NSPredicate, on store: HKHealthStore) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let q = HKSampleQuery(sampleType: HKCategoryType(.mindfulSession),
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(underlying: error))
                    return
                }
                let total = (samples ?? []).reduce(0.0) { acc, sample in
                    acc + sample.endDate.timeIntervalSince(sample.startDate) / 60.0
                }
                continuation.resume(returning: total)
            }
            store.execute(q)
        }
    }

    private func sleepMinutes(predicate: NSPredicate, on store: HKHealthStore) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let q = HKSampleQuery(sampleType: HKCategoryType(.sleepAnalysis),
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(underlying: error))
                    return
                }
                let total = (samples ?? []).compactMap { $0 as? HKCategorySample }
                    .filter { sample in
                        if let v = HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                            return v == .inBed
                                || v == .asleepUnspecified
                                || v == .asleepCore
                                || v == .asleepDeep
                                || v == .asleepREM
                        }
                        return false
                    }
                    .reduce(0.0) { acc, sample in
                        acc + sample.endDate.timeIntervalSince(sample.startDate) / 60.0
                    }
                continuation.resume(returning: total)
            }
            store.execute(q)
        }
    }
}
