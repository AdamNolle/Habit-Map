import XCTest
@testable import HabitMapCore

/// Exhaustive boundary table for `CellLevel.from(progress:)`. These thresholds
/// drive every heatmap cell's colour, so the edges must not drift.
final class CellLevelTests: XCTestCase {
    func test_zeroProgress_isEmpty() {
        XCTAssertEqual(CellLevel.from(progress: 0.0), .empty)
    }

    func test_justAboveZero_isP25() {
        XCTAssertEqual(CellLevel.from(progress: 0.001), .p25)
        XCTAssertEqual(CellLevel.from(progress: 0.0011), .p25)
    }

    func test_belowEmptyThreshold_isEmpty() {
        XCTAssertEqual(CellLevel.from(progress: 0.0009), .empty)
    }

    func test_p25_upperEdge() {
        XCTAssertEqual(CellLevel.from(progress: 0.25), .p25)
        XCTAssertEqual(CellLevel.from(progress: 0.2599), .p25)
    }

    func test_p50_band() {
        XCTAssertEqual(CellLevel.from(progress: 0.26), .p50)
        XCTAssertEqual(CellLevel.from(progress: 0.50), .p50)
        XCTAssertEqual(CellLevel.from(progress: 0.5099), .p50)
    }

    func test_p75_band() {
        XCTAssertEqual(CellLevel.from(progress: 0.51), .p75)
        XCTAssertEqual(CellLevel.from(progress: 0.75), .p75)
        XCTAssertEqual(CellLevel.from(progress: 0.7599), .p75)
    }

    func test_p100_band() {
        XCTAssertEqual(CellLevel.from(progress: 0.76), .p100)
        XCTAssertEqual(CellLevel.from(progress: 1.0), .p100)
    }

    func test_overflowProgress_clampsToP100() {
        XCTAssertEqual(CellLevel.from(progress: 1.5), .p100)
    }

    func test_allCasesRoundTripRawValue() {
        for level in CellLevel.allCases {
            XCTAssertEqual(CellLevel(rawValue: level.rawValue), level)
        }
    }
}
