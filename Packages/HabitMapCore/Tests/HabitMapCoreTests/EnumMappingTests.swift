import XCTest
@testable import HabitMapCore

/// Raw-value stability for the persisted enums. The raw strings are written to
/// SwiftData (`typeRaw`, `healthMetricRaw`, `sourceRaw`); drifting a case name
/// would silently orphan existing records, so pin them.
final class EnumMappingTests: XCTestCase {
    func test_habitType_rawRoundTrip() {
        for type in HabitType.allCases {
            XCTAssertEqual(HabitType(rawValue: type.rawValue), type)
        }
        XCTAssertEqual(HabitType.manualOnce.rawValue, "manualOnce")
        XCTAssertEqual(HabitType.autoHealth.rawValue, "autoHealth")
        XCTAssertEqual(HabitType.inverse.rawValue, "inverse")
    }

    func test_healthMetric_rawRoundTrip() {
        let all: [HealthMetric] = [.stepCount, .workouts, .mindfulMinutes, .sleep, .standHours,
                                   .activeEnergy, .hydration, .distanceWalkingRunning, .heartRate]
        for metric in all {
            XCTAssertEqual(HealthMetric(rawValue: metric.rawValue), metric)
        }
        XCTAssertEqual(HealthMetric.stepCount.rawValue, "stepCount")
        XCTAssertNil(HealthMetric(rawValue: "notAMetric"))
    }

    func test_completionSource_rawRoundTrip() {
        let all: [CompletionSource] = [.manual, .health, .watch, .siri, .widget]
        for source in all {
            XCTAssertEqual(CompletionSource(rawValue: source.rawValue), source)
        }
        XCTAssertEqual(CompletionSource.health.rawValue, "health")
    }

    func test_completionSource_defaultsToManualOnUnknown() {
        let completion = HabitCompletion(date: .startOfToday())
        completion.sourceRaw = "garbage"
        XCTAssertEqual(completion.source, .manual)
    }
}
