import XCTest
import HealthKit
@testable import HabitMapCore

final class HealthKitServiceTests: XCTestCase {
    func test_objectTypeMappings_coverAllMetrics() {
        for metric in [HealthMetric.stepCount, .activeEnergy, .standHours, .hydration,
                       .distanceWalkingRunning, .heartRate, .workouts, .mindfulMinutes, .sleep] {
            XCTAssertNotNil(HealthKitService.objectType(for: metric),
                            "Missing HKObjectType mapping for \(metric)")
        }
    }

    func test_quantityTypeMapping_excludesNonQuantityMetrics() {
        XCTAssertNotNil(HealthKitService.quantityType(for: .stepCount))
        XCTAssertNil(HealthKitService.quantityType(for: .workouts))
        XCTAssertNil(HealthKitService.quantityType(for: .mindfulMinutes))
        XCTAssertNil(HealthKitService.quantityType(for: .sleep))
    }

    func test_unitMapping_returnsExpectedUnits() {
        XCTAssertEqual(HealthKitService.unit(for: .stepCount), .count())
        XCTAssertEqual(HealthKitService.unit(for: .activeEnergy), .kilocalorie())
        XCTAssertEqual(HealthKitService.unit(for: .distanceWalkingRunning), .meter())
        XCTAssertNil(HealthKitService.unit(for: .workouts))
        XCTAssertNil(HealthKitService.unit(for: .mindfulMinutes))
    }

    func test_isAvailable_matchesHKHealthStore() {
        let service = HealthKitService()
        XCTAssertEqual(service.isAvailable, HKHealthStore.isHealthDataAvailable())
    }
}
